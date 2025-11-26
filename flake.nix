{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    hooks,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;

    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    forAllSystems = f:
      lib.genAttrs systems (system:
        f {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [self.overlays.default];
          };

          inherit system;
        });
  in {
    overlays.default = final: prev: {
      cppToolchain = with prev.llvmPackages_latest; [
        clang
        clang-tools
        lld
        libcxx
        libstdcxxClang
      ];
    };

    devShells = forAllSystems ({
      pkgs,
      system,
    }: let
      check = self.checks.${system}.pre-commit-check;
    in {
      default = pkgs.mkShell {
        inherit (check) shellHook;

        packages =
          check.enabledPackages
          ++ (with pkgs; [
            gcc
            gnumake
            pkg-config
            ncurses
            cppToolchain
            gdb
            valgrind
          ]);

        env = {
          CC = "clang";
          CXX = "clang++";
        };
      };
    });

    packages = forAllSystems ({
      pkgs,
      system,
    }: let
      name = "haka_${system}";
    in {
      default = pkgs.stdenv.mkDerivation {
        pname = "haka";
        version = "1.0.0";

        src = ./.;

        nativeBuildInputs = with pkgs; [
          gnumake
          pkg-config
        ];

        buildInputs = with pkgs;
          [ncurses]
          ++ pkgs.cppToolchain;

        buildPhase = ''
          TARGET=${name} make
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp ${name} $out/bin/
        '';
      };
    });

    checks = forAllSystems ({
      system,
      pkgs,
      ...
    }: {
      pre-commit-check = hooks.lib.${system}.run {
        src = ./.;
        package = pkgs.prek;
        hooks = {
          clang-format.enable = true;
          clang-tidy.enable = true;
          alejandra.enable = true;
          convco.enable = true;

          statix = {
            enable = true;
            settings.ignore = ["/.direnv"];
          };
        };
      };
    });

    formatter =
      forAllSystems ({pkgs, ...}: pkgs.alejandra);
  };
}
