self: super:
let
  sourceInfo = import ./sources/clawdis-source.nix;
  clawdisGateway = super.callPackage ./packages/clawdis-gateway.nix {
    inherit sourceInfo;
  };
  clawdisSetup = super.writeShellScriptBin "clawdis-setup" ''
    echo "clawdis-setup: guided setup coming soon" >&2
    echo "Use docs/zero-to-clawdis.md for now." >&2
    exit 1
  '';
  clawdisDoctor = super.writeShellScriptBin "clawdis-doctor" ''
    config="$HOME/.clawdis/clawdis.json"
    if [ ! -f "$config" ]; then
      echo "clawdis-doctor: missing config at $config" >&2
      exit 1
    fi
    echo "clawdis-doctor: config found at $config"
    exit 0
  '';
in {
  clawdis-gateway = clawdisGateway;
  clawdis-setup = clawdisSetup;
  clawdis-doctor = clawdisDoctor;
}
