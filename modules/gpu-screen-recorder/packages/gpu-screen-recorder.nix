{
  stdenv,
  fetchgit,
  lib,
  libGL,
  libdrm,
  libpulseaudio,
  libcap,
  libva,
  vulkan-headers,
  libX11,
  libXcomposite,
  libXrandr,
  libXfixes,
  libXdamage,
  ffmpeg-full,
  egl-wayland,
  wayland,
  wayland-scanner,
  dbus,
  pipewire,
  meson,
  cmake,
  ninja,
  pkg-config,
  addDriverRunpath,
  wrapperDir ? "/run/wrappers/bin",
  ...
}:
with stdenv; let
  hash = "sha256-yS0FL0sVLXs5pXd+8ej42yz6CcCznVu8jlkc0yKpuo4=";
  deriv = mkDerivation (finalAttrs: rec {
    pname = "gpu-screen-recorder-${hash}";
    version = "5.5.10";
    outputs = ["build" "out"];
    phases = ["setupPhase" "configurePhase" "buildPhase" "fixupPhase"];

    src = fetchgit {
      inherit hash;
      name = "gsr-${version}";
      url = "https://repo.dec05eba.com/gpu-screen-recorder";
      rev = "2290f0641c91317c4fd05f35d2c0cfc25fba2181";
    };

    nativeBuildInputs = [
      pkg-config
      cmake
      meson
      ninja
    ];

    buildInputs = [
      libX11
      libXcomposite
      libXrandr
      libXfixes
      libXdamage

      ffmpeg-full
      vulkan-headers

      libpulseaudio
      libcap

      egl-wayland
      wayland-scanner
      wayland

      libGL # libglvnd
      libdrm
      libva

      dbus
      pipewire
    ];

    configurePhase = ''
      meson configure --prefix=$out --buildtype=release -Dstrip=true $build
    '';

    setupPhase = ''
      cd $src
      meson setup $build $src
    '';

    buildPhase = ''
      ninja -C $build install
    '';

    sourceRoot = ".";

    postInstall = let
      libraryPath = "${
        lib.makeLibraryPath ([
            libGL
            addDriverRunpath.driverLink
          ]
          ++ buildInputs)
      }";
    in lib.traceVal ''
      mkdir -p $out/bin/.wrapped
      mv $out/gpu-screen-recorder $out/bin/.wrapped/
      makeWrapper "$out/bin/.wrapped/gpu-screen-recorder" "$out/bin/gpu-screen-recorder" \
        --prefix LD_LIBRARY_PATH : "${libGL}/lib" \
        --prefix LD_LIBRARY_PATH : "${libraryPath}" \
        --prefix PATH : "${wrapperDir}" \
        --prefix PATH : "${libraryPath}" \
        --suffix PATH : "$out/bin"
        --suffix PATH : "$out"
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
  });
in
  lib.trace deriv.outPath (lib.trace libGL.outPath deriv)
