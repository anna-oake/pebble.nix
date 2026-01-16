{
  mkShellNoCC,
  lib,
  nodejs,
  pebble-qemu,
  pebble-tool,
  gcc-arm-embedded-13,
  pebble-sdk,
}:
{
  devServerIP ? "",
  emulatorTarget ? "",
  cloudPebble ? false,
  nativeBuildInputs ? [ ],
  packages ? [ ],
  CFLAGS ? "",
  ...
}@attrs:
let
  rest = removeAttrs attrs [
    "cloudPebble"
    "devServerIP"
    "emulatorTarget"
    "nativeBuildInputs"
    "name"
    "packages"
    "CFLAGS"
  ];
in
mkShellNoCC (
  {
    name = "pebble-env";
    packages = [
      nodejs
      pebble-qemu
      pebble-tool
      gcc-arm-embedded-13
    ]
    ++ packages
    ++ nativeBuildInputs;

    env = {
      CFLAGS =
        "-Wno-error=builtin-macro-redefined -Wno-error=builtin-declaration-mismatch -include sys/types.h "
        + CFLAGS;
      PEBBLE_PHONE = devServerIP;
      PEBBLE_EMULATOR = emulatorTarget;
      PEBBLE_CLOUDPEBBLE = if cloudPebble then "1" else "";
      PEBBLE_EXTRA_PATH = lib.makeBinPath [
        pebble-qemu
      ];
      PEBBLE_SDKS_PATH = pebble-sdk;
    };
  }
  // rest
)
