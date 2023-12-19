{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        rustVersion = (pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml);
        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustVersion;
          rustc = rustVersion;
        };
      in {
        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ 
            bashInteractive
            taplo
            cmake
            openssl
            pkg-config
            udev
            libusb

            # clang
            llvmPackages.bintools 
            llvmPackages.libclang 
            protobuf
            sccache


            # No yarn2nix for now
            nodePackages_latest.typescript
            nodejs
            yarn
            python311
            solc-select

          ];
          buildInputs = with pkgs; [ 
              (rustVersion.override { extensions = [ "rust-src" ]; }) 
          ];
          
        };
  });
}
