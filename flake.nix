{
  edition = 201909;
  description = "github.com/makepad/makepad";
  inputs = {
    "import-cargo" = {
      url = "git+https://github.com/edolstra/import-cargo";
    };
    nixpkgs = {
      uri = "nixpkgs/release-19.09";
    };
    moz_overlay_src = {
      url = "git+https://github.com/mozilla/nixpkgs-mozilla";
      flake = false;
    };
  };
  outputs = {self, nixpkgs, import-cargo, moz_overlay_src}:
    let
      moz_overlay = import moz_overlay_src;

      systems = [ "x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ moz_overlay self.overlay ];
        }
      );

    in rec {
      overlay = final: prev: rec {
        # To update:
        # DATE=$(curl -s https://static.rust-lang.org/dist/channel-rust-stable.toml | grep 'date =' | awk -F '"' '{ print $2; }')
        # nix-prefetch-url https://static.rust-lang.org/dist/$DATE/channel-rust-stable.toml
        rust = with final; (rustChannelOf {
          channel = "stable";
          date = "2019-11-07";
          sha256 = "0pyps2gjd42r8js9kjglad7mifax96di0xjjmvbdp3izbiin390r";
        }).rust;

        makepad = with final; with pkgs; stdenv.mkDerivation {
            name = "makepad";

            src = self;

            buildInputs = [
              rust
              (import-cargo.builders.importCargo {
                lockFile = ./Cargo.lock;
                inherit pkgs;
              }).cargoHome
            ] ++ lib.optional (system == "x86_64-darwin") [ darwin.apple_sdk.frameworks.AppKit ];

            buildPhase = ''
              cargo build --frozen --offline
            '';

            # checkPhase currently fails on macOS due to makepad-glx-sys trying to link -lGLX
            #doCheck = true;
            #checkPhase = ''
            #  cargo test --frozen --offline
            #'';
            doCheck = false;

            installPhase = ''
              mkdir -p $out/bin
              cargo install --frozen --offline --path makepad --root $out
              rm $out/.crates.toml
            '';
        };
      };

      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) rust makepad;
      });

      defaultPackage = forAllSystems (system: self.packages.${system}.makepad);
    }
  ;
}
