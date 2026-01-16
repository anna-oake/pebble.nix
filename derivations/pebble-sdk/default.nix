{
  stdenvNoCC,
  pkgs,
}:
let
  nodeEnv = (pkgs.callPackage ./nodeEnv { }).nodeDependencies;
  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      freetype-py
      sh
      pypng
    ]
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pebble-sdk";
  version = "4.9.77";

  src = fetchTarball {
    url = "https://sdk.core.store/releases/${finalAttrs.version}/sdk-core.tar.gz";
    sha256 = "0l1gxd9aian6xbpgx64px7pps3215sn1jamav9hjmd86civws2q4";
  };

  nativeBuildInputs = [ pythonEnv ];

  postUnpack = ''
    TIMESTAMP=0

    find "source" -name '._*' -type f -delete

    substituteInPlace "source/sdk-core/pebble/common/tools/inject_metadata.py" \
      --replace-fail "'timestamp' : timestamp," "'timestamp' : $TIMESTAMP," \
      --replace-fail "RESOURCE_TIMESTAMP_ADDR, '<L', timestamp)" "RESOURCE_TIMESTAMP_ADDR, '<L', $TIMESTAMP)"

    substituteInPlace "source/sdk-core/pebble/common/tools/mkbundle.py" \
      --replace-fail "generated_at = int(time.time())" "generated_at = $TIMESTAMP" \
      --replace-fail "socket.gethostname()" "'nix'" \
      --replace-fail "'timestamp' : firmware_timestamp" "'timestamp' : $TIMESTAMP" \
      --replace-fail "'timestamp' : resources_timestamp" "'timestamp' : $TIMESTAMP" \
      --replace-fail "'timestamp': app_timestamp" "'timestamp': $TIMESTAMP" \
      --replace-fail "'timestamp': worker_timestamp" "'timestamp': $TIMESTAMP"
  '';

  installPhase = ''
    python3 sdk-core/pebble/waf --help >/dev/null 2>&1 || true

    SDK_PATH="$out/current"
    mkdir -p $SDK_PATH

    mv sdk-core $SDK_PATH

    ln -s "${nodeEnv}/lib/node_modules" "$SDK_PATH/node_modules"
    ln -s "${pythonEnv}" "$SDK_PATH/.venv"

    ln -s $SDK_PATH "$out/${finalAttrs.version}"
  '';
})
