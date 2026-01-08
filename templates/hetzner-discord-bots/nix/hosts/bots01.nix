{ ... }:

let
  fleet = import ../../configs/fleet.nix;
in {
  imports = [
    ../modules/clawdbot-fleet.nix
  ];

  networking.hostName = "bots01";
  time.timeZone = "Europe/Vienna";
  system.stateVersion = "25.11";

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 REPLACE_WITH_YOUR_PUBLIC_KEY admin"
    ];
  };

  services.clawdbotFleet = {
    enable = true;
    bots = fleet.bots;
    guildId = fleet.guildId;
    routing = fleet.routing;
    wireguard.adminPeerPublicKey = "REPLACE_WITH_YOUR_WG_PUBLIC_KEY";
  };
}
