#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p cacert coreutils curl gnugrep gnupg gnused jq libxml2.bin

set -eux -o pipefail

source_dir="${0%/*}"

# Set up a secure temporary directory with automatic cleanup.
original_umask="$(umask)"
umask 077
tmpdir=
cleanup() {
  [ -n "$tmpdir" ] && rm -rf "$tmpdir" ||:
}
trap cleanup EXIT
tmpdir="$(mktemp -d)"

# Set up a clean environment.
mkdir "$tmpdir/home"
export HOME="$tmpdir/home"
mkdir "$tmpdir/gnupghome"
export GNUPGHOME="$tmpdir/gnupghome"

# Get the signing key to verify the signatures on hash lists.
gpg --receive-keys 14F26682D0916CDD81E37B6D61B7B526D98F0353

declare -A releaseUrl releaseList
getReleaseList() {
  local app="$1" && shift
  if [ -n "${releaseUrl[$app]:-}" ] && [ -n "${releaseList[$app]:-}" ]; then
    return 0
  fi
  local url="https://archive.mozilla.org/pub/${app}/releases/"
  local index="$tmpdir/releaseIndex-$app"
  local list="$tmpdir/releaseList-$app"
  curl --silent -o "$index" "$url"
  xmllint --html --xpath '//a/text()' "$index" | \
    sed -e '/^[^0-9]/d' -e '/funnelcake/d' -e 's,/$,,' -e '/b/d' -e '/rc/d' | \
    sort --reverse --version-sort \
    > "$list"
  releaseUrl[$app]="$url"
  releaseList[$app]="$list"
}

getAppLatestVersion() {
  local app="$1" && shift
  local majorNumber="$1" && shift
  local maybeESR="$1" && shift

  getReleaseList "$app"
  cat "${releaseList[$app]}" | \
    if [ -n "$majorNumber" ]; then
      grep "^${majorNumber}\."
    else
      cat
    fi | \
    if [ -n "$maybeESR" ]; then
      grep -m 1 'esr$'
    else
      grep -m 1 -v 'esr$'
    fi
}

declare -A appMajorToVersion
processAppNameWithVersion() {
  local nameWithVersion="$1" && shift
  local app="${nameWithVersion%-*}"
  local version="${nameWithVersion##*-}"
  local majorNumber="${version%%.*}"
  local maybeESR=
  if [ -z "${version##*esr}" ]; then
    maybeESR=esr
  fi
  if [ -z "${appMajorToVersion[${app}:${majorNumber}:${maybeESR}]:-}" ]; then
    getReleaseList "$app"
    local latestVersion="$( getAppLatestVersion "$app" "$majorNumber" "$maybeESR" )" ||:
    if [ -n "$latestVersion" ]; then
      appMajorToVersion[${app}:${majorNumber}:${maybeESR}]="$latestVersion"
    fi
  fi
}

# Parse the command line.
for nameWithVersion in "$@"; do
  processAppNameWithVersion "$nameWithVersion"
done

# Add latest versions for all mentioned apps.
declare -A allApps
for appKey in "${!appMajorToVersion[@]}"; do
  app="${appKey%%:*}"
  majorNumber="${appKey#*:}"
  maybeESR="${majorNumber#*:}"
  majorNumber="${majorNumber%%:*}"
  maybeESR="${maybeESR%%:*}"
  allApps[$app:$maybeESR]=1
done
for appKey in "${!allApps[@]}"; do
  app="${appKey%%:*}"
  maybeESR="${appKey##*:}"
  latestVersion="$( getAppLatestVersion "$app" "" "$maybeESR" )"
  processAppNameWithVersion "$app-$latestVersion"
done

# Process all requested apps and versions.
for appKey in "${!appMajorToVersion[@]}"; do
  app="${appKey%%:*}"
  majorNumber="${appKey#*:}"
  maybeESR="${majorNumber#*:}"
  majorNumber="${majorNumber%%:*}"
  maybeESR="${maybeESR%%:*}"
  version="${appMajorToVersion[$appKey]}"
  majorKey="${majorNumber}${maybeESR}"
  url="${releaseUrl[$app]}"

  curl --silent -o $HOME/shasums "$url$version/SHA512SUMS"
  curl --silent -o $HOME/shasums.asc "$url$version/SHA512SUMS.asc"
  gpgv --keyring=$GNUPGHOME/pubring.kbx $HOME/shasums.asc $HOME/shasums

  for arch in linux-x86_64 linux-i686; do
    cat "$HOME/shasums" | \
      ( grep -F "${arch}" || true ) | \
      ( grep '\.xpi$' || true ) | \
      while read -r sha512 filename rest; do
        this_url="${url}${version}/${filename}"
        this_locale="${filename##*/}"
        this_locale="${this_locale%.xpi}"
        cat >> "$tmpdir/sources.mjson" <<EOF
{
  "${app}": {
    "${majorKey}": {
      "${arch}": {
        "${this_locale}": {
          "version": "${version}",
          "url": "${this_url}",
          "sha512": "${sha512}"
        }
      }
    }
  }
}
EOF
      done
  done
done

jq -Sn 'reduce inputs as $x ({}; . * $x)' < "$tmpdir/sources.mjson" > "$tmpdir/sources.json"

mv "$tmpdir/sources.json" "$source_dir/sources.json"
