{
  description = "nix-clawdis: declarative Nix packaging + configuration for Clawdis";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = import ./nix/overlay.nix;
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          clawdis-gateway = pkgs.clawdis-gateway;
          clawdis-setup = pkgs.clawdis-setup;
          clawdis-doctor = pkgs.clawdis-doctor;
          default = pkgs.clawdis-gateway;
        };

        apps = {
          clawdis = flake-utils.lib.mkApp { drv = pkgs.clawdis-gateway; };
          clawdis-setup = flake-utils.lib.mkApp { drv = pkgs.clawdis-setup; };
          clawdis-doctor = flake-utils.lib.mkApp { drv = pkgs.clawdis-doctor; };
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.nixfmt-rfc-style
            pkgs.nil
          ];
        };
      }
    ) // {
      overlays.default = overlay;
      homeManagerModules.clawdis = import ./nix/modules/home-manager/clawdis.nix;
      darwinModules.clawdis = import ./nix/modules/darwin/clawdis.nix;
    };
}
