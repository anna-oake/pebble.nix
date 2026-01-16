{
  pkgs,
  nixpkgs,
  pebble-tool,
  system,
}:
{
  name,
  version,
  src,
  nativeBuildInputs ? [ ],
  postUnpack ? "",
  CFLAGS ? "",
  ...
}@rest:
let
  pkgsCross = import nixpkgs {
    inherit system;
    crossSystem = nixpkgs.lib.systems.examples.arm-embedded;
  };
in
pkgsCross.gccStdenv.mkDerivation (
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

    nativeBuildInputs = [
      pebble-tool
      pkgs.strip-nondeterminism
      pkgs.lndir
    ]
    ++ nativeBuildInputs;

    postUnpack = ''
      export PEBBLE_SDKS_PATH="${pkgs.pebble-sdk}"

      # writable paths
      export HOME=`pwd`/home-dir
      TMPDIR="$PWD/tmp"
      mkdir -p "$TMPDIR"
      export PEBBLE_SDK_TMP_PATH="$TMPDIR/pebble-sdk"
    ''
    + postUnpack;

    CFLAGS =
      "-Wno-error=builtin-macro-redefined -Wno-error=builtin-declaration-mismatch -include sys/types.h "
      + CFLAGS;

    LDFLAGS = "-Wl,--build-id=none";

    buildPhase = ''
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
