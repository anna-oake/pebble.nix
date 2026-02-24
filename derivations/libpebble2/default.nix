{
  fetchFromGitHub,
  python3Packages,
}:
python3Packages.buildPythonPackage {
  pname = "libpebble2";
  version = "0.0.31";

  src = fetchFromGitHub {
    owner = "pebble-dev";
    repo = "libpebble2";
    rev = "b7013d01bd6f6d10f7528fcf9557591d5e8cbb3a";
    hash = "sha256-4waUs0QeMI0dWL5Dk1HwL/5pK2uOfCFyJaK1MuRkuBw=";
  };

  propagatedBuildInputs = with python3Packages; [
    pyserial
    six
    websocket-client
  ];

  format = "pyproject";

  build-system = with python3Packages; [
    setuptools
  ];
}
