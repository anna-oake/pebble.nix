{
  stdenv,
  lib,
  fetchFromGitHub,
  autoconf,
  automake,
  bison,
  flex,
  glib,
  libtool,
  perl,
  pixman,
  pkg-config,
  python2,
  SDL2,
  zlib,
  apple-sdk_15,
  xorg,
}:
let
  darwinDeps = lib.optional stdenv.isDarwin apple-sdk_15;
  x11Deps = lib.optionals stdenv.isLinux (
    with xorg;
    [
      libX11
      libXext
      libXi
      libXrandr
      libXcursor
      libXinerama
      libXfixes
    ]
  );
in
stdenv.mkDerivation {
  name = "pebble-qemu";
  version = "2.5.0-pebble8";

  src = fetchFromGitHub {
    owner = "coredevices";
    repo = "qemu";
    rev = "a0da0db291d92d491b4883cec01ba8f088ef5b3b";
    hash = "sha256-DVep6uwHw/1oyzHLYmWQPu6taD2bRkmcq/pA6PsY2Fc=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    autoconf
    automake
    bison
    flex
    libtool
    perl
    pkg-config
    python2
  ];

  buildInputs = [
    glib
    pixman
    SDL2
    zlib
  ]
  ++ x11Deps
  ++ darwinDeps;

  configureFlags = [
    "--with-coroutine=gthread"
    "--disable-werror"
    "--disable-mouse"
    "--disable-vnc"
    "--disable-cocoa"
    "--enable-debug"
    "--enable-sdl"
    "--with-sdlabi=2.0"
    "--target-list=arm-softmmu"
    "--extra-cflags=-DSTM32_UART_NO_BAUD_DELAY"
    "--extra-ldflags=-g"
  ];

  postInstall = ''
    mv $out/bin/qemu-system-arm $out/bin/qemu-pebble
  '';

  patches = [
    ./skip-macos-icon.patch
  ];

  meta = with lib; {
    homepage = "https://github.com/pebble/qemu";
    description = "Fork of QEMU with support for Pebble devices";
    license = licenses.gpl2Plus;
    mainProgram = "qemu-pebble";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
