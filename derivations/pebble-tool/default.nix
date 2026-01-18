{
  lib,
  fetchFromGitHub,
  makeWrapper,
  pypkjs,
  freetype,
  nodejs,
  python3Packages,
  zlib,
}:
let
  rpath = lib.makeLibraryPath [
    freetype
    zlib
  ];

  sourcemap = python3Packages.buildPythonPackage rec {
    pname = "sourcemap";
    version = "0.2.1";

    src = fetchFromGitHub {
      owner = "mattrobenolt";
      repo = "python-sourcemap";
      tag = version;
      hash = "sha256-xVVBtwYPAsScYitINnKhj3XOgapXzQnXvmuF0B4Kuac=";
    };

    format = "pyproject";

    build-system = with python3Packages; [
      setuptools
    ];
  };

  libpebble2 = python3Packages.buildPythonPackage {
    pname = "libpebble2";
    version = "0.0.30";
    src = fetchFromGitHub {
      owner = "pebble-dev";
      repo = "libpebble2";
      rev = "6d0e8cffca29eb2ed4a876ea87c50df9c31ad3e7";
      hash = "sha256-jzN3bMp7hCCFP6wQ4woXTgOmehczvn7cLqen9TlG7Dc=";
    };

    patches = [
      ./libpebble2-add-gabbro.patch
    ];

    propagatedBuildInputs = with python3Packages; [
      pyserial
      six
      websocket-client
    ];

    format = "pyproject";

    build-system = with python3Packages; [
      setuptools
    ];
  };
in
python3Packages.buildPythonApplication rec {
  pname = "pebble-tool";
  version = "5.0.22";

  src = fetchFromGitHub {
    owner = "coredevices";
    repo = "pebble-tool";
    tag = "v${version}";
    hash = "sha256-wFA9fvznnwci+f2U2o4VXiyXyTEOZZp26Dx6nXG/a+g=";
  };

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ nodejs ];

  dependencies = with python3Packages; [
    pypkjs
    colorama
    httplib2
    libpebble2
    oauth2client
    packaging
    progressbar2
    pyasn1
    pyasn1-modules
    pypng
    pyqrcode
    pyserial
    requests
    rsa
    six
    sourcemap
    websocket-client
    wheel

    freetype-py
    websockify
    cobs
  ];

  patches = [
    ./copy-micro-flash.patch
    ./add-emu-gabbro.patch
  ];

  postPatch = ''
    substituteInPlace pyproject.toml --replace "rsa>=4.9.1" "rsa>=4.9"

    substituteInPlace pebble_tool/sdk/__init__.py \
        --replace-fail \
        'tmp_link = "/var/tmp/pebble-sdk"' \
        'tmp_link = os.environ.get("PEBBLE_SDK_TMP_PATH", "/var/tmp/pebble-sdk")'

    substituteInPlace pebble_tool/sdk/__init__.py \
        --replace-fail \
        'sdk_manager = SDKManager()' \
        'sdk_manager = SDKManager(os.environ.get("PEBBLE_SDKS_PATH"))'
  '';

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ nodejs ]}"
    "--prefix PYTHONPATH : \"$PYTHONPATH\""
    "--prefix LD_LIBRARY_PATH : ${rpath}"
    "--prefix DYLD_LIBRARY_PATH : ${rpath}"
  ];

  format = "pyproject";

  build-system = with python3Packages; [
    hatchling
  ];

  meta = with lib; {
    homepage = "https://developer.rebble.io/developer.pebble.com/index.html";
    description = "Tool for interacting with the Pebble SDK";
    license = licenses.mit;
    mainProgram = "pebble";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
