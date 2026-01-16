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
  type,
  description,
  releaseNotes,
  category ? "",
  banner ? "",
  smallIcon ? "",
  largeIcon ? "",
  screenshots ? { },
  homepage ? "",
  sourceUrl ? "",
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

  stringNotEmpty = str: builtins.isString str && str != "";

  metaYaml =
    with pkgs.lib;
    let
      screenshotPaths = builtins.concatLists (attrValues screenshots);
      assets =
        let
          allDeviceUrls = if screenshots ? all then screenshots.all else [ ];
          devices = removeAttrs screenshots [ "all" ];
        in
        builtins.concatStringsSep "\n" (
          mapAttrsToList (name: urls: ''
            - name: ${name}
              screenshots:
            ${builtins.concatStringsSep "\n" (map (url: "    - ${url}") urls ++ allDeviceUrls)}
          '') devices
        );

      categoryMap = {
        "Daily" = "5261a8fb3b773043d500000c";
        "Tools & Utilities" = "5261a8fb3b773043d500000f";
        "Notifications" = "5261a8fb3b773043d5000001";
        "Remotes" = "5261a8fb3b773043d5000008";
        "Health & Fitness" = "5261a8fb3b773043d5000004";
        "Games" = "5261a8fb3b773043d5000012";
      };
      categoryProp = if builtins.hasAttr category categoryMap then categoryMap.${category} else "Faces";

      indentString = str: "  " + (builtins.replaceStrings [ "\n" ] [ "\n  " ] str);
    in
    assert asserts.assertMsg (stringNotEmpty name) "name cannot be empty";
    assert asserts.assertMsg (stringNotEmpty description) "description cannot be empty";
    assert asserts.assertMsg (stringNotEmpty releaseNotes) "releaseNotes cannot be empty";
    assert asserts.assertOneOf "type" type [
      "watchface"
      "watchapp"
    ];
    assert
      if type == "watchapp" then
        let
          validCategories = builtins.attrNames categoryMap;
        in
        if elem category validCategories then
          true
        else
          builtins.trace "category must be one of ${generators.toPretty { } validCategories}, but is ${generators.toPretty { } category}" false
      else
        true;
    assert
      if type == "watchapp" then
        asserts.assertMsg (stringNotEmpty banner) "banner must point to a file"
      else
        true;
    assert
      if type == "watchapp" then
        asserts.assertMsg (stringNotEmpty largeIcon) "largeIcon must point to a file"
      else
        true;
    assert
      if type == "watchapp" then
        asserts.assertMsg (stringNotEmpty smallIcon) "smallIcon must point to a file"
      else
        true;
    assert asserts.assertMsg (
      (builtins.length screenshotPaths) > 0
    ) "At least 1 screenshot must be provided";
    builtins.toFile "meta.yml" ''
      pbw_file: ${name}.pbw
      header: ${banner}
      description: |
      ${indentString description}
      assets:
      ${assets}
      category: ${categoryProp}
      title: ${name}
      source: ${sourceUrl}
      type: ${type}
      website: ${homepage}
      release_notes: |
      ${indentString releaseNotes}
      small_icon: ${smallIcon}
      large_icon: ${largeIcon}
    '';
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

    installPhase =
      let
        screenshotPaths = pkgs.lib.flatten (builtins.attrValues screenshots);
      in
      ''
        mkdir -p $out
        mkdir -p \
          ${builtins.concatStringsSep " " (map (path: "$out/${dirOf path}") screenshotPaths)} \
          $out/${dirOf banner} \
          $out/${dirOf largeIcon} \
          $out/${dirOf smallIcon}

        cp ${metaYaml} $out/meta.yml
        cp build/$(basename `pwd`).pbw "$out/${name}.pbw"
        strip-nondeterminism --type zip "$out/${name}.pbw"
        ${builtins.concatStringsSep "\n" (map (path: "cp ${path} $out/${path}") screenshotPaths)}

      ''
      + pkgs.lib.optionalString (stringNotEmpty banner) ''
        cp ${banner} $out/${banner}
      ''
      + pkgs.lib.optionalString (stringNotEmpty largeIcon) ''
        cp ${largeIcon} $out/${largeIcon}
      ''
      + pkgs.lib.optionalString (stringNotEmpty smallIcon) ''
        cp ${smallIcon} $out/${smallIcon}
      ''
      + ''

        cd $out
        tar --owner=0 --group=0 --numeric-owner --format=gnu \
            --sort=name --mtime="@0" \
            -czf appstore-bundle.tar.gz *
      '';
  }
  // (removeAttrs rest [
    "name"
    "src"
    "nativeBuildInputs"
    "postUnpack"
    "screenshots"
  ])
)
