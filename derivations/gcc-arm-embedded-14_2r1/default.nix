{
  gcc-arm-embedded,
  fetchurl,
  stdenv,
}:
gcc-arm-embedded.overrideAttrs (old: rec {
  version = "14.2.rel1";
  src = fetchurl {
    url = "https://developer.arm.com/-/media/Files/downloads/gnu/${version}/binrel/arm-gnu-toolchain-${version}-${old.platform}-arm-none-eabi.tar.xz";
    hash =
      {
        aarch64-darwin = "sha256-x8eP+rm+v86R2Z08JNpr9LgcAeFs9VHrL/nyW54KOBg=";
        aarch64-linux = "sha256-hzMLqwhd2HSdTtCtYzZ0udxIsje2EGnjtIGr02TQpoQ=";
        x86_64-linux = "sha256-YqY7mB/jkanLrX71Gxfkmuqj57DQKbNsoenDsqm3iCM=";
      }
      .${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
  };
})
