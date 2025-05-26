{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        pkgs = import nixpkgs {inherit system;};
        name = "haka_${system}";
      in {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            inherit name;
            src = ./.;

            nativeBuildInputs = with pkgs; [
              gnumake
              pkg-config
            ];

            buildInputs = with pkgs; [
              clang-tools
              pkgs.llvmPackages_latest.libstdcxxClang
              pkgs.llvmPackages_latest.libcxx
              ncurses
            ];

            buildPhase = ''
              TARGET=${name} make
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp ${name} $out/bin
            '';
          };
        };
      }
    );
}
