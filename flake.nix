{
  description = "Tools for building Pebble apps on Nix systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
      ...
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ] (
      system:
      let
        config = {
          permittedInsecurePackages = [
            "python-2.7.18.12"
            "python-2.7.18.12-env"
          ];
        };
        pkgs = import nixpkgs {
          inherit system config;
          overlays = [ self.overlays.default ];
        };
      in
      rec {
        pebbleEnv = pkgs.callPackage ./buildTools/pebbleEnv.nix { };

        buildPebbleApp = import ./buildTools/buildPebbleApp.nix {
          inherit pkgs nixpkgs system;
          pebble-tool = packages.pebble-tool;

        };
        packages = {
          inherit (pkgs)
            pdc-sequencer
            pdc_tool
            pebble-qemu
            pebble-tool
            pypkjs
            pebble-sdk
            ;
        };

        checks = packages;
      }
    )
    // {
      overlays.default = final: prev: {
        pdc-sequencer = final.callPackage ./derivations/pdc-sequencer.nix { };
        pdc_tool = final.callPackage ./derivations/pdc_tool.nix { };
        pebble-qemu = final.callPackage ./derivations/pebble-qemu { };
        pebble-tool = final.callPackage ./derivations/pebble-tool { };
        pypkjs = final.callPackage ./derivations/pebble-tool/pypkjs.nix { };
        pebble-sdk = final.callPackage ./derivations/pebble-sdk { };
      };

      templates = rec {
        basic = {
          path = ./templates/basic;
          description = "A simple pebble.nix project, with a development shell for building Pebble apps";
          welcomeText = ''
            # Next Steps
            - Check out the Pebble Developer docs: https://developer.rebble.io
            - See what else pebble.nix can do: https://github.com/pebble-dev/pebble.nix
            - Join us in the Rebble Discord server, and get help writing Pebble apps in #app-dev: https://discordapp.com/invite/aRUAYFN
          '';
        };

        default = basic;
      };
    };
}
