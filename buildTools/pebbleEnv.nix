{
  mkShellNoCC,
  lib,
  nodejs,
  pebble-qemu,
  pebble-tool,
  gcc-arm-embedded,
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
      gcc-arm-embedded
    ]
    ++ packages
    ++ nativeBuildInputs;

    env = {
      inherit CFLAGS;
      PEBBLE_PHONE = devServerIP;
      PEBBLE_EMULATOR = emulatorTarget;
      PEBBLE_CLOUDPEBBLE = if cloudPebble then "1" else "";
      PEBBLE_EXTRA_PATH = lib.makeBinPath [
        pebble-qemu
      ];
    };
  }
  // rest
)
