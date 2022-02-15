{ lib, stdenv, fetchFromGitHub, cmake, pkg-config, python3, libX11, libXext, libXinerama, libXrandr, libXft, libXfixes, libXrender
, freetype, asciidoc, libxslt, coreutils, procps, xdotool, xorgserver, xsetroot, xterm, runtimeShell
, nixosTests
}:

stdenv.mkDerivation rec {
  pname = "herbstluftwm";
  version = "0.9.3+${suffix}";
  suffix = "git20220211_${lib.substring 0 7 src.rev}";

  src = fetchFromGitHub {
    owner = "herbstluftwm";
    repo = "herbstluftwm";
    rev = "5517222fda4d10a7681e4eb59d9ba5a21cea8243";
    hash = "sha256-v5im6+wMSzOei4MnSnvBbg7RNcKCwuECjigdi71VuVc=";
  };

  outputs = [
    "out"
    "doc"
    "man"
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_SYSCONF_PREFIX=${placeholder "out"}/etc"
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
    libxslt.bin
  ];

  depsBuildBuild = [
    asciidoc
  ];

  buildInputs = [
    libX11
    libXext
    libXinerama
    libXrandr
    libXft
    libXfixes
    libXrender
    freetype
  ];

  patches = [
    ./test-path-environment.patch
  ];

  postPatch = ''
    patchShebangs doc/gendoc.py doc/format-doc.py doc/patch-manpage-xml.py

    # fix /etc/xdg/herbstluftwm paths in documentation and scripts
    grep -rlZ /etc/xdg/herbstluftwm share/ doc/ scripts/ | while IFS="" read -r -d "" path; do
      substituteInPlace "$path" --replace /etc/xdg/herbstluftwm $out/etc/xdg/herbstluftwm
    done

    # fix shebang in generated scripts
    substituteInPlace tests/conftest.py --replace "/usr/bin/env bash" ${runtimeShell}
    substituteInPlace tests/test_autostart.py --replace "/usr/bin/env bash" ${runtimeShell}
    substituteInPlace tests/test_herbstluftwm.py --replace "/usr/bin/env bash" ${runtimeShell}

    # workaround for PATH not getting used in some cases
    substituteInPlace doc/patch-manpage-xml.py --replace "'xsltproc'" "'${libxslt.bin}/bin/xsltproc'"
    substituteInPlace tests/test_autostart.py --replace "'ps'" "'${procps}/bin/ps'"
    substituteInPlace tests/test_herbstluftwm.py --replace "'touch'" "'${coreutils}/bin/touch'"
  '';

  doCheck = true;

  checkInputs = [
    (python3.withPackages (ps: with ps; [ ewmh pytest xlib ]))
    xdotool
    xorgserver
    xsetroot
    xterm
    python3.pkgs.pytestCheckHook
  ];

  # make the package's module avalaible
  preCheck = ''
    export PYTHONPATH="$PYTHONPATH:../python"
  '';

  pytestFlagsArray = [ "../tests" ];
  disabledTests = [
    "test_title_different_letters_are_drawn"
  ];

  passthru = {
    tests.herbstluftwm = nixosTests.herbstluftwm;
  };

  meta = with lib; {
    description = "A manual tiling window manager for X";
    homepage = "https://herbstluftwm.org/";
    license = licenses.bsd2;
    platforms = platforms.linux;
    maintainers = with maintainers; [ thibautmarty ];
  };
}
