{
  stdenv,
  fetchgit,
  lib,
  libGL,
  meson,
  cmake,
  ninja,
  pkg-config,

  wayland,
  wayland-scanner,
  egl-wayland,

  libX11,
  libXrandr,
  libXcursor,
  libXrender,
  libXcomposite,
  libXfixes,
  libXext,
  libXi,

  addDriverRunpath,
  wrapperDir ? "/run/wrappers/bin",

  ...
}:
with stdenv;
  mkDerivation (finalAttrs: rec {
    pname = "gpu-screen-recorder-notification";
    version = "1.0.7";
    outputs = ["build" "out"];
    phases = ["setupPhase" "configurePhase" "buildPhase" "fixupPhase"];

    src = fetchgit {
      name = "gsr-notify";
      url = "https://repo.dec05eba.com/gpu-screen-recorder-notification";
      rev = "1d193407d1cdb25a9f89f549f288bf9dbb84e135";
      hash = "sha256-hdsbQewnqSJvWEW9HaFuVf6vDAY5CDCGxVFsxZJ4Yh8=";
    };

    nativeBuildInputs = [
      pkg-config
      cmake
      meson
      ninja
    ];

    buildInputs = [
      libX11
      libXrandr
      libXcursor
      libXrender
      libXcomposite
      libXfixes
      libXext
      libXi

      libGL # libglvnd
      wayland-scanner
      egl-wayland
      wayland
    ];

    configurePhase = ''
      meson configure --prefix=$out --buildtype=release -Dstrip=true $build
    '';

    setupPhase = ''
      cd $src; meson setup $build $src
    '';

    buildPhase = ''
      ninja -C $build install
    '';

    postInstall = let
      libraryPath = "${
        lib.makeLibraryPath ([
            libGL
            addDriverRunpath.driverLink
          ]
          ++ buildInputs)
      }";

    in ''
      mkdir -p $out/bin/.wrapped 
      mv $out/gsr-notify $out/bin/.wrapped/
      makeWrapper "$out/bin/.wrapped/gsr-notify" "$out/bin/gsr-notify" \
        --prefix LD_LIBRARY_PATH : "${libraryPath}" \
        --prefix PATH : "${wrapperDir}" \
        --prefix PATH : "${libraryPath}" \
        --suffix PATH : "$out/bin"
    '';

    meta = with lib; {
      description = "A program that produces a familiar, friendly greeting";
      longDescription = ''
        GNU Hello is a program that prints "Hello, world!" when you run it.
        It is fully customizable.
      '';
      homepage = "https://www.gnu.org/software/hello/manual/";
      license = licenses.gpl3Plus;
      maintainers = with maintainers; [eelco];
      platforms = platforms.all;
    };
  })
