final: prev:
let
  packages = import ./packages { pkgs = prev; };
in
packages // {
  clawdbotPackages = packages;
}
