{
  lib,
  pkgs,
  stdenvNoCC,
  fetchFromGitHub,
  gcc-arm-embedded-13,
  llvmPackages,
  python3,
  nodejs,
  gettext,
  emscripten,
  nanopb,
  which,
  patchelf,
  pkg-config,
  glib,
  freetype,
  gtk3,
  withGabbro ? true,
  withEmery ? true,
  withFlint ? true,
  withDiorite ? true,
  withChalk ? true,
  withBasalt ? true,
  withAplite ? false,
}:
let
  libpebble2 = python3.pkgs.buildPythonPackage {
    pname = "libpebble2";
    version = "0.0.31";
    src = fetchFromGitHub {
      owner = "pebble-dev";
      repo = "libpebble2";
      rev = "b7013d01bd6f6d10f7528fcf9557591d5e8cbb3a";
      hash = "sha256-4waUs0QeMI0dWL5Dk1HwL/5pK2uOfCFyJaK1MuRkuBw=";
    };

    propagatedBuildInputs = with python3.pkgs; [
      pyserial
      six
      websocket-client
    ];

    format = "pyproject";

    build-system = with python3.pkgs; [
      setuptools
    ];
  };

  pythonBuildEnv = python3.withPackages (
    ps: with ps; [
      pillow
      freetype-py
      ply
      pyusb
      pyserial
      sh
      pypng
      pexpect
      cobs
      svg-path
      requests
      gitpython
      pyelftools
      pycryptodome
      mock
      prompt-toolkit
      bitarray
      pep8
      polib
      intelhex
      protobuf
      grpcio-tools
      certifi
      libclang
      packaging
      libpebble2
      pyftdi
    ]
  );

  nodeEnv = (pkgs.callPackage ./nodeEnv { }).nodeDependencies;
  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      freetype-py
      sh
      pypng
    ]
  );
in
assert lib.asserts.assertMsg (!withAplite) "aplite is not supported yet";
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pebble-sdk";
  version = "4.9.127";

  src = fetchFromGitHub {
    owner = "coredevices";
    repo = "PebbleOS";
    tag = "v${finalAttrs.version}";
    hash = "sha256-b01mCfF5wcDUY0GTh3X4piUWWzFFpLqWXnX67tt+04U=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    gcc-arm-embedded-13
    llvmPackages.clang
    nodejs
    gettext
    emscripten
    nanopb
    pythonBuildEnv
    which
    patchelf
  ]
  ++ lib.optionals stdenvNoCC.isLinux [
    pkg-config
    glib.dev
    freetype.dev
    gtk3.dev
  ];

  patches = [
    ./patches/skip-tool-check.patch
    ./patches/gitinfo-version.patch
    ./patches/fix-clang-spelling.patch
    ./patches/skip-npm-install.patch
    ./patches/fix-libpebble-determinism.patch
    ./patches/fix-asm-debug-prefix-map.patch
  ];

  postPatch = ''
    substituteInPlace sdk/waf/wscript \
      --replace-fail '"zip/waflib.zip", "w",' '"zip/waflib.zip", "w", strict_timestamps=False,'

    substituteInPlace third_party/moddable/moddable/build/makefiles/mac/tools.mk \
      --replace-fail "echo '#!/bin/bash\\nDIR=" "printf '#!${pkgs.bash}/bin/bash\\nDIR="

    substituteInPlace third_party/moddable/moddable/build/makefiles/lin/tools.mk \
      --replace-fail "SHELL = /bin/dash" "SHELL = /bin/sh" \
      --replace-fail "'#!/bin/bash\\nDIR=" "'#!${pkgs.bash}/bin/bash\\nDIR="

    patchShebangs waf third_party/jerryscript/jerryscript/js_tooling
  '';

  hardeningDisable = [
    "fortify"
  ];

  preBuild = ''
    export HOME="$TMPDIR"

    export SOURCE_DATE_EPOCH="1700578963"

    export PEBBLE_GIT_TAG="v${finalAttrs.version}"
    export PEBBLE_GIT_COMMIT="v${finalAttrs.version}"
    export PEBBLE_GIT_TIMESTAMP="$SOURCE_DATE_EPOCH"
    export PEBBLE_SKIP_NPM_INSTALL=1

    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONHASHSEED=0
    export PYTHONNOUSERSITE=1

    export EM_CACHE="$TMPDIR/emscripten-cache"
    export MACOS_VERSION_MIN="-mmacosx-version-min=10.12"

    toolchain_prefix_map="-ffile-prefix-map=${gcc-arm-embedded-13}=/toolchain -fdebug-prefix-map=${gcc-arm-embedded-13}=/toolchain -fmacro-prefix-map=${gcc-arm-embedded-13}=/toolchain"
    debug_prefix_map="-ffile-prefix-map=$PWD=/source -fdebug-prefix-map=$PWD=/source -fmacro-prefix-map=$PWD=/source $toolchain_prefix_map"
    random_seed="-frandom-seed=pebble-sdk"
    warning_compat="-Wno-error=maybe-uninitialized"
    export CFLAGS="''${CFLAGS:-} $debug_prefix_map $random_seed $warning_compat"
    export CXXFLAGS="''${CXXFLAGS:-} $debug_prefix_map $random_seed $warning_compat"
    export LINKFLAGS="''${LINKFLAGS:-} $debug_prefix_map"

    lto_prefix_map="-Wl,-plugin-opt=-ffile-prefix-map=$PWD=/source -Wl,-plugin-opt=-fdebug-prefix-map=$PWD=/source -Wl,-plugin-opt=-fmacro-prefix-map=$PWD=/source -Wl,-plugin-opt=$random_seed"
    export LDFLAGS="''${LDFLAGS:-} $lto_prefix_map"

    unset CC CXX AR AS OBJCOPY LD RANLIB STRIP STRINGS

    export NANOPB_GENERATOR="${pythonBuildEnv}/bin/python3 $PWD/third_party/nanopb/nanopb/generator/nanopb_generator.py"

    configure_and_build_board() {
      local board="$1"
      local platform_name="$2"

      echo "Building for board: $board (platform: $platform_name)"

      ./waf configure --qemu --board "$board" --release --sdkshell
      ./waf build qemu_image_micro qemu_image_spi

      mkdir -p build/sdk/"$platform_name"/qemu
      mv build/qemu_micro_flash.bin build/sdk/"$platform_name"/qemu/
      mv build/qemu_spi_flash.bin build/sdk/"$platform_name"/qemu/
      mv build/src/fw/tintin_fw.elf build/sdk/"$platform_name"/qemu/"$platform_name"_sdk_debug.elf
      bzip2 build/sdk/"$platform_name"/qemu/qemu_spi_flash.bin
    }
  '';

  buildPhase = lib.concatStringsSep "\n" (
    [
      "runHook preBuild"
    ]
    ++ lib.optional withGabbro "configure_and_build_board 'spalding_gabbro' 'gabbro'"
    ++ lib.optional withEmery "configure_and_build_board 'snowy_emery' 'emery'"
    ++ lib.optional withFlint "configure_and_build_board 'silk_flint' 'flint'"
    ++ lib.optional withDiorite "configure_and_build_board 'silk_bb2' 'diorite'"
    ++ lib.optional withChalk "configure_and_build_board 'spalding_bb2' 'chalk'"
    ++ lib.optional withBasalt "configure_and_build_board 'snowy_bb2' 'basalt'"
    ++ [
      "runHook postBuild"
    ]
  );

  postBuild = ''
    python3 build/sdk/waf --help >/dev/null 2>&1 || true

    mkdir -p sdk-core
    cp -r build/sdk sdk-core/pebble

    mv sdk-core/pebble/package.json sdk-core/
    mv sdk-core/pebble/use_requirements.json sdk-core/
    mv sdk-core/pebble/requirements.txt sdk-core/

    waf_extras_dir="$(find sdk-core/pebble -type d -path '*/waflib/extras' | head -n 1)"
    if [ -z "$waf_extras_dir" ]; then
      echo "Unable to locate waf extras directory in packaged SDK output"
      exit 1
    fi

    substituteInPlace "$waf_extras_dir/pebble_sdk.py" \
      --replace-fail "from waflib import Logs" $'from waflib import Logs\nimport sdk_paths'

    substituteInPlace "$waf_extras_dir/pebble_sdk.py" \
      --replace-fail "from process_sdk_resources import generate_resources" $'from process_sdk_resources import generate_resources\nimport report_memory_usage'

    substituteInPlace "$waf_extras_dir/pebble_sdk_common.py" \
      --replace-fail "from waflib.Tools import c,c_preproc" $'from waflib.Tools import c,c_preproc\nimport ldscript,process_bundle,process_headers,process_js,report_memory_usage,xcode_pebble'

    substituteInPlace "$waf_extras_dir/pebble_sdk_lib.py" \
      --replace-fail "from process_sdk_resources import generate_resources" $'import sdk_paths\nfrom process_sdk_resources import generate_resources'

    substituteInPlace "$waf_extras_dir/process_sdk_resources.py" \
      --replace-fail "from resources.resource_map import resource_generator" $'from resources.resource_map import resource_generator\nimport resources.resource_map.resource_generator_bitmap\nimport resources.resource_map.resource_generator_font\nimport resources.resource_map.resource_generator_js\nimport resources.resource_map.resource_generator_pbi\nimport resources.resource_map.resource_generator_png\nimport resources.resource_map.resource_generator_raw'

    requirements="$(cat sdk-core/use_requirements.json)"
    printf '{\n  "requirements": %s,\n  "version": "%s",\n  "type": "sdk-core",\n  "channel": ""\n}\n' \
      "$requirements" \
      "${finalAttrs.version}" \
      > sdk-core/manifest.json

    find "sdk-core/pebble" -name 'Doxyfile-SDK.auto' -type f \
      | while read -r file; do
          substituteInPlace "$file" --replace-fail "$NIX_BUILD_TOP" ""
        done

    export TIMESTAMP="1700578963"

    substituteInPlace "sdk-core/pebble/common/tools/inject_metadata.py" \
    --replace-fail "\"timestamp\": timestamp," "\"timestamp\": $TIMESTAMP," \
    --replace-fail "RESOURCE_TIMESTAMP_ADDR, \"<L\", timestamp)" "RESOURCE_TIMESTAMP_ADDR, \"<L\", $TIMESTAMP)"

    substituteInPlace "sdk-core/pebble/common/tools/mkbundle.py" \
    --replace-fail "generated_at = int(time.time())" "generated_at = $TIMESTAMP" \
    --replace-fail "socket.gethostname()" "'nix'" \
    --replace-fail "\"timestamp\": firmware_timestamp" "\"timestamp\": $TIMESTAMP" \
    --replace-fail "\"timestamp\": resources_timestamp" "\"timestamp\": $TIMESTAMP" \
    --replace-fail "\"timestamp\": app_timestamp" "\"timestamp\": $TIMESTAMP" \
    --replace-fail "\"timestamp\": worker_timestamp" "\"timestamp\": $TIMESTAMP"
  '';

  installPhase = ''
    SDK_PATH="$out/current"
    mkdir -p $SDK_PATH

    mv sdk-core $SDK_PATH

    ln -s "${nodeEnv}/lib/node_modules" "$SDK_PATH/node_modules"
    ln -s "${pythonEnv}" "$SDK_PATH/.venv"

    ln -s $SDK_PATH "$out/${finalAttrs.version}"
  '';
})
