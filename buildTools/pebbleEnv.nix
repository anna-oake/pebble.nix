{
  mkShellNoCC,
  lib,
  pkgs,
}:
{
  devServerIP ? "",
  emulatorTarget ? "emery",
  cloudPebble ? false,
  nativeBuildInputs ? [ ],
  packages ? [ ],
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
    packages =
      with pkgs;
      [
        pebble-qemu
        pebble-tool
        gcc-arm-embedded-13
        pdc-sequencer
        pdc_tool
      ]
      ++ packages
      ++ nativeBuildInputs;

    env = {
      CFLAGS = "-Wno-error=builtin-macro-redefined -Wno-error=builtin-declaration-mismatch";
      PEBBLE_PHONE = devServerIP;
      PEBBLE_EMULATOR = emulatorTarget;
      PEBBLE_CLOUDPEBBLE = if cloudPebble then "1" else "";
      PEBBLE_SDKS_PATH = pkgs.pebble-sdk;
      PEBBLE_EXTRA_PATH = lib.makeBinPath [
        pkgs.pebble-qemu
        pkgs.gcc-arm-embedded-13
      ];
    };
  }
  // rest
)
