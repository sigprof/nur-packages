{
  baseName ? "firefox",
  basePath ? "pkgs/mozilla-langpack",
  baseUrl ? "http://archive.mozilla.org/pub/${baseName}/releases/",
  coreutils,
  curl,
  gnugrep,
  gnupg,
  gnused,
  jq,
  runtimeShell,
  writeScript,
  xidel,
}:
writeScript "update-mozilla-langpack" ''
  #!${runtimeShell}
  PATH=${coreutils}/bin:${gnused}/bin:${gnugrep}/bin:${xidel}/bin:${curl}/bin:${gnupg}/bin:${jq}/bin
  set -eux
  pushd ${basePath}

  HOME=`mktemp -d`
  export GNUPGHOME=`mktemp -d`

  gpg --receive-keys 14F26682D0916CDD81E37B6D61B7B526D98F0353

  tmpfile=`mktemp`
  tmpfile2=`mktemp`
  url=${baseUrl}

  # retriving latest released version
  #  - extracts all links from the $url
  #  - removes . and ..
  #  - this line remove everything not starting with a number
  #  - this line sorts everything with semver in mind
  #  - we remove lines that are mentioning funnelcake
  #  - remove beta versions
  # - this line pick up latest release
  version=`xidel -s $url --extract "//a" | \
           sed s"/.$//" | \
           grep "^[0-9]" | \
           sort --version-sort | \
           grep -v "funnelcake" | \
           grep -e "\([[:digit:]]\|[[:digit:]][[:digit:]]\)$" | grep -v "b" | \
           tail -1`

  curl --silent -o $HOME/shasums "$url$version/SHA256SUMS"
  curl --silent -o $HOME/shasums.asc "$url$version/SHA256SUMS.asc"
  gpgv --keyring=$GNUPGHOME/pubring.kbx $HOME/shasums.asc $HOME/shasums

  # this is a list of sha256 and tarballs for both arches
  # Upstream files contains python repr strings like b'somehash', hence the sed dance
  shasums=`cat $HOME/shasums | sed -E s/"b'([a-f0-9]{64})'?(.*)"/'\1\2'/ | grep .xpi`

  cat > $tmpfile <<EOF
  {
    "${baseName}": {
      "$version": [
  EOF
  delim=
  for arch in linux-x86_64 linux-i686; do
    # retriving a list of all tarballs for each arch
    #  - only select tarballs for current arch
    #  - only select tarballs for current version
    #  - rename space with colon so that for loop doesnt
    #  - inteprets sha and path as 2 lines
    for line in `echo "$shasums" | \
                 grep $arch | \
                 grep "\\.xpi$" | \
                 tr " " ":"`; do
      # create an entry for every locale
      cat >> $tmpfile <<EOF
        $delim{ "url": "$url$version/`echo $line | cut -d":" -f3`",
          "locale": "`echo $line | cut -d":" -f3 | sed "s/$arch\/xpi\///" | sed "s/\.xpi$//"`",
          "arch": "$arch",
          "sha256": "`echo $line | cut -d":" -f1`"
        }
  EOF
      delim=,
    done
  done
  cat >> $tmpfile <<EOF
      ]
    }
  }
  EOF

  {
    if [ -s langpack_sources.json ]; then
      cat langpack_sources.json
    fi
    cat $tmpfile
  } | jq -n 'reduce inputs as $x ({}; . + $x)' > $tmpfile2

  mv $tmpfile2 langpack_sources.json

  popd
''
