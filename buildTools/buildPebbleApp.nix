{
  pkgs,
}:
{
  name,
  version,
  src,
  nativeBuildInputs ? [ ],
  CFLAGS ? "",
  ...
}@rest:
pkgs.stdenvNoCC.mkDerivation (
  {
    pname = builtins.replaceStrings [ " " ] [ "-" ] name;
    inherit version;

    src =
      let
        fs = pkgs.lib.fileset;
        root = src;
      in
      fs.toSource {
        inherit root;
        fileset = fs.unions [
          (root + "/src")
          (root + "/package.json")
          (fs.maybeMissing (root + "/wscript"))
          (fs.maybeMissing (root + "/resources"))
        ];
      };

    nativeBuildInputs =
      with pkgs;
      [
        pebble-tool
        strip-nondeterminism
        gcc-arm-embedded-13
      ]
      ++ nativeBuildInputs;

    CFLAGS = "-Wno-error=builtin-macro-redefined -Wno-error=builtin-declaration-mismatch " + CFLAGS;

    LDFLAGS = "-Wl,--build-id=none";

    buildPhase = ''
      export PEBBLE_SDKS_PATH="${pkgs.pebble-sdk}"

      # writable paths
      export HOME=`pwd`/home-dir
      TMPDIR="$PWD/tmp"
      mkdir -p "$TMPDIR"
      export PEBBLE_SDK_TMP_PATH="$TMPDIR/pebble-sdk"

      pebble clean
      pebble build
    '';

    installPhase = ''
      mkdir -p $out
      cp build/$(basename `pwd`).pbw "$out/${name}.pbw"
      strip-nondeterminism --type zip "$out/${name}.pbw"
    '';
  }
  // (removeAttrs rest [
    "name"
    "src"
    "nativeBuildInputs"
    "postUnpack"
  ])
)
