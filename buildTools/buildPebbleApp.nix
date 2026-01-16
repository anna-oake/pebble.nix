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

  nodeEnv = (pkgs.callPackage ./nodeEnv { }).nodeDependencies;
  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      freetype-py
      sh
      pypng
    ]
  );

  sdkVersion = "4.9.77";

  pebble-sdk = fetchTarball {
    url = "https://sdk.core.store/releases/${sdkVersion}/sdk-core.tar.gz";
    sha256 = "0l1gxd9aian6xbpgx64px7pps3215sn1jamav9hjmd86civws2q4";
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
      pythonEnv
      pkgs.nodejs
      pkgs.strip-nondeterminism
    ]
    ++ nativeBuildInputs;

    postUnpack = ''
      # Setup Pebble SDK
      export HOME=`pwd`/home-dir
      SDK_VER="${sdkVersion}"

      # canonical location (Linux-style)
      PERSIST="$HOME/.pebble-sdk"
      SDK_ROOT="$PERSIST/SDKs/$SDK_VER"

      mkdir -p "$SDK_ROOT/sdk-core"
      cp -r ${pebble-sdk}/sdk-core "$SDK_ROOT/"

      ln -sfn ${pythonEnv} "$SDK_ROOT/.venv"
      ln -sfn ${nodeEnv}/lib/node_modules "$SDK_ROOT/node_modules"

      ln -sfn "$SDK_ROOT" "$PERSIST/SDKs/current"

      # Darwin
      mkdir -p "$HOME/Library/Application Support"
      ln -sfn "$PERSIST" "$HOME/Library/Application Support/Pebble SDK"

      chmod -R u+w "$HOME"

      export TMPDIR="$PWD/tmp"
      mkdir -p "$TMPDIR"
      export PEBBLE_SDK_TMP_LINK="$TMPDIR/pebble-sdk"

      TIMESTAMP=0

      substituteInPlace "$SDK_ROOT/sdk-core/pebble/common/tools/inject_metadata.py" \
        --replace-fail "'timestamp' : timestamp," "'timestamp' : $TIMESTAMP," \
        --replace-fail "RESOURCE_TIMESTAMP_ADDR, '<L', timestamp)" "RESOURCE_TIMESTAMP_ADDR, '<L', $TIMESTAMP)"

      substituteInPlace "$SDK_ROOT/sdk-core/pebble/common/tools/mkbundle.py" \
        --replace-fail "generated_at = int(time.time())" "generated_at = $TIMESTAMP" \
        --replace-fail "socket.gethostname()" "'nix'" \
        --replace-fail "'timestamp' : firmware_timestamp" "'timestamp' : $TIMESTAMP" \
        --replace-fail "'timestamp' : resources_timestamp" "'timestamp' : $TIMESTAMP" \
        --replace-fail "'timestamp': app_timestamp" "'timestamp': $TIMESTAMP" \
        --replace-fail "'timestamp': worker_timestamp" "'timestamp': $TIMESTAMP"
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
