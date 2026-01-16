{
  description = "Tools for building Pebble apps on Nix systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      lib = nixpkgs.lib;
      derivationsDir = ./derivations;
      derivationNames = lib.attrNames (
        lib.filterAttrs (_: type: type == "directory") (builtins.readDir derivationsDir)
      );
      eachSystem =
        systems: f:
        let
          perSystem = lib.genAttrs systems f;
          addSystem = system: attrs: lib.mapAttrs (_: v: { ${system} = v; }) attrs;
        in
        lib.foldl' lib.recursiveUpdate { } (lib.mapAttrsToList addSystem perSystem);
    in
    (eachSystem
      [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ]
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              permittedInsecurePackages = [
                "python-2.7.18.12"
                "python-2.7.18.12-env"
              ];
            };
            overlays = [ self.overlays.default ];
          };
          packages = lib.genAttrs derivationNames (name: pkgs.${name});
        in
        {
          inherit packages;
          checks = packages;

          pebbleEnv = pkgs.callPackage ./buildTools/pebbleEnv.nix { };

          buildPebbleApp = import ./buildTools/buildPebbleApp.nix {
            inherit pkgs;
          };

          mkAppInstallPbw =
            {
              pbwPackage,
              emulatorTarget ? "emery",
              withLogs ? true,
            }:
            {
              type = "app";
              program =
                let
                  args =
                    (lib.optional (emulatorTarget != "") "--emulator ${emulatorTarget}")
                    ++ lib.optional withLogs "--logs";
                  installApp = pkgs.writeShellApplication {
                    name = "install-${pbwPackage.pname}";
                    runtimeInputs = [
                      pkgs.pebble-qemu
                    ];
                    runtimeEnv = {
                      PEBBLE_SDKS_PATH = pkgs.pebble-sdk;
                      PEBBLE_EXTRA_PATH = lib.makeBinPath [
                        pkgs.pebble-qemu
                      ];
                    };
                    text = ''
                      set -euo pipefail
                      exec ${pkgs.pebble-tool}/bin/pebble install "${pbwPackage}/${pbwPackage.pname}.pbw" ${lib.concatStringsSep " " args} "$@"
                    '';
                  };
                in
                "${installApp}/bin/install-${pbwPackage.pname}";
            };
        }
      )
    )
    // {
      overlays.default =
        final: prev:
        lib.genAttrs derivationNames (name: final.callPackage (derivationsDir + "/${name}") { });

      templates = rec {
        basic = {
          path = ./templates/basic;
          description = "A simple pebble.nix project, with a development shell for building Pebble apps";
          welcomeText = ''
            # Next Steps
            - Check out the Pebble Developer docs: https://developer.rebble.io
            - See what else pebble.nix can do: https://github.com/anna-oake/pebble.nix
            - Join the Rebble Discord server, and get help writing Pebble apps in #app-dev: https://discordapp.com/invite/aRUAYFN
          '';
        };

        default = basic;
      };
    };
}
