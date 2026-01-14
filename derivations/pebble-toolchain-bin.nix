{
  stdenv,
  lib,
  fetchzip,
  autoPatchelfHook,

  expat,
  ncurses5,
  python2,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "pebble-toolchain-bin";
  version = "4.9";

  src =
    (rec {
      x86_64-linux = fetchzip {
        url = "https://sdk.core.store/releases/${finalAttrs.version}/toolchain-linux.tar.gz";
        hash = "sha256-2Yuut6KmAndecSHKfqGMw8/Z/Dm0A5EHxdIhfHl7R94=";
        stripRoot = false;
      };
      x86_64-darwin = fetchzip {
        url = "https://sdk.core.store/releases/${finalAttrs.version}/toolchain-mac.tar.gz";
        hash = "sha256-i4vjZ26CRDYAiReO2WHCR0JjH9JBFTUi/iCSkmCS+Rs=";
        stripRoot = false;
      };
      aarch64-darwin = x86_64-darwin;
    }).${stdenv.hostPlatform.system};

  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = [
    python2
  ]
  ++ (lib.optionals stdenv.hostPlatform.isLinux [
    expat
    ncurses5
    python2
    zlib
  ]);

  installPhase = ''
    mv toolchain-*/arm-none-eabi $out
  '';
})
