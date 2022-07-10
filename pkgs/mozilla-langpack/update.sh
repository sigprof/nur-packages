#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p cacert coreutils curl gnugrep gnupg gnused jq libxml2.bin

set -eux -o pipefail

source_dir="${0%/*}"

# Set up a secure temporary directory with automatic cleanup.
tmpdir=
cleanup() {
  [ -n "$tmpdir" ] && rm -rf "$tmpdir" ||:
}
trap cleanup EXIT
tmpdir="$(mktemp -d)"

# Set up a clean environment.
umask 077
mkdir "$tmpdir/home"
export HOME="$tmpdir/home"
mkdir "$tmpdir/gnupghome"
export GNUPGHOME="$tmpdir/gnupghome"

# Parse the command line.
baseName="$1" && shift
declare -a majorVersions
majorVersions=("$@")

gpg --receive-keys 14F26682D0916CDD81E37B6D61B7B526D98F0353

url="https://archive.mozilla.org/pub/${baseName}/releases/"

curl --silent -o "$tmpdir/index.html" "$url"
allVersions="$(
  xmllint --html --xpath '//a/text()' "$tmpdir/index.html" | \
    sed -e '/^[^0-9]/d' -e '/funnelcake/d' -e 's,/$,,' -e '/b/d' -e '/rc/d' | \
    sort --version-sort
)"

declare -a neededVersions
for major in "${majorVersions[@]}"; do
  majorNum="${major%%esr}"
  if [ "$majorNum" = "$major" ]; then
    isESR=
  else
    isESR=t
  fi
  version="$(
    printf '%s\n' "$allVersions" | \
      grep -E "^${majorNum}\." | \
      if [ -n "$isESR" ]; then
        grep 'esr$'
      else
        grep -v 'esr$'
      fi | \
      tail -1
  )"
  neededVersions+=("$version")
done
latestNonESRVersion="$(
  printf '%s\n' "$allVersions" |
  grep -v 'esr$' | \
  tail -1
)"
latestESRVersion="$(
  printf '%s\n' "$allVersions" |
  grep 'esr$' | \
  tail -1
)"
neededVersions+=("$latestNonESRVersion" "$latestESRVersion")

versionList="$(
  printf '%s\n' "${neededVersions[@]}" | \
    sort --version-sort -u
)"

for version in $versionList; do
  majorVersion="${version%%.*}"
  if [ -z "${version##*esr}" ]; then
    majorVersion="${majorVersion}esr"
  fi
  curl --silent -o $HOME/shasums "$url$version/SHA256SUMS"
  curl --silent -o $HOME/shasums.asc "$url$version/SHA256SUMS.asc"
  gpgv --keyring=$GNUPGHOME/pubring.kbx $HOME/shasums.asc $HOME/shasums

  for arch in linux-x86_64 linux-i686; do
    < "$HOME/shasums" \
      grep -F "${arch}" | \
      grep '\.xpi$' | \
      while read -r sha256 filename rest; do
        this_url="${url}${version}/${filename}"
        this_locale="${filename##*/}"
        this_locale="${this_locale%.xpi}"
        cat >> "$tmpdir/sources.mjson" <<EOF
{
  "${baseName}": {
    "${majorVersion}": {
      "${arch}": {
        "${this_locale}": {
          "url": "${this_url}",
          "sha256": "${sha256}"
        }
      }
    }
  }
}
EOF
      done
  done
done

jq -n 'reduce inputs as $x ({}; . * $x)' < "$tmpdir/sources.mjson" > "$tmpdir/sources.json"

mv "$tmpdir/sources.json" "$source_dir/sources.json"
