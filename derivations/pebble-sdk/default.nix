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
    version = "0.0.30";
    src = fetchFromGitHub {
      owner = "pebble-dev";
      repo = "libpebble2";
      rev = "6d0e8cffca29eb2ed4a876ea87c50df9c31ad3e7";
      hash = "sha256-jzN3bMp7hCCFP6wQ4woXTgOmehczvn7cLqen9TlG7Dc=";
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
  version = "4.9.116";

  src = fetchFromGitHub {
    owner = "coredevices";
    repo = "PebbleOS";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ZWh8vIJ+y97z2jz8dtsuE7cJAwjRuORt7jhLCOvVGh4=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    gcc-arm-embedded-13
    llvmPackages.clang
    llvmPackages.lld
    nodejs
    gettext
    emscripten
    nanopb
    pythonBuildEnv
    which
    patchelf
  ]
  ++ lib.optionals (stdenvNoCC.hostPlatform.system == "x86_64-linux") [
    pkgs.gcc_multi
  ];

  patches = [
    ./patches/skip-tool-check.patch
    ./patches/gitinfo-version.patch
    ./patches/fix-clang-spelling.patch
    ./patches/skip-npm-install.patch
    ./patches/fix-libpebble-determinism.patch
    ./patches/fix-asm-debug-prefix-map.patch
    ./patches/disable-fw-build-id.patch
  ]
  ++ lib.optionals (stdenvNoCC.hostPlatform.system == "x86_64-linux") [
    ./patches/use-gcc-multi-32bit.patch
  ];

  postPatch = ''
    substituteInPlace sdk/waf/wscript \
      --replace-fail '"zip/waflib.zip", "w",' '"zip/waflib.zip", "w", strict_timestamps=False,'
    patchShebangs waf third_party/jerryscript/jerryscript/js_tooling
  '';

  hardeningDisable = [
    "zerocallusedregs"
  ];

  preBuild = ''
    export HOME="$TMPDIR"

    export PEBBLE_GIT_TAG="v${finalAttrs.version}"
    export PEBBLE_GIT_COMMIT="v${finalAttrs.version}"
    export PEBBLE_GIT_TIMESTAMP="1700578963"
    export PEBBLE_SKIP_NPM_INSTALL=1

    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONHASHSEED=0
    export PYTHONNOUSERSITE=1

    export EM_CACHE="$TMPDIR/emscripten-cache"

    debug_prefix_map="-ffile-prefix-map=$PWD=/source -fdebug-prefix-map=$PWD=/source -fmacro-prefix-map=$PWD=/source"
    random_seed="-frandom-seed=pebble-sdk"
    export CFLAGS="''${CFLAGS:-} $debug_prefix_map $random_seed"
    export CXXFLAGS="''${CXXFLAGS:-} $debug_prefix_map $random_seed"
    export LINKFLAGS="''${LINKFLAGS:-} $debug_prefix_map"
    lto_prefix_map="-Wl,-plugin-opt=-ffile-prefix-map=$PWD=/source -Wl,-plugin-opt=-fdebug-prefix-map=$PWD=/source -Wl,-plugin-opt=-fmacro-prefix-map=$PWD=/source -Wl,-plugin-opt=$random_seed"
    export LDFLAGS="''${LDFLAGS:-} $lto_prefix_map"

    unset CC CXX AR AS OBJCOPY LD RANLIB STRIP

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

    requirements="$(cat sdk-core/use_requirements.json)"
    printf '{\n  "requirements": %s,\n  "version": "%s",\n  "type": "sdk-core",\n  "channel": ""\n}\n' \
      "$requirements" \
      "${finalAttrs.version}" \
      > sdk-core/manifest.json

    find "sdk-core/pebble" -name 'Doxyfile-SDK.auto' -type f \
      | while read -r file; do
          substituteInPlace "$file" --replace-fail "$NIX_BUILD_TOP" ""
        done
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
