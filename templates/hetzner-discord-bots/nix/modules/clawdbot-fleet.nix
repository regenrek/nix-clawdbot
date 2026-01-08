{ config, lib, pkgs, nix-clawdbot, ... }:

let
  cfg = config.services.clawdbotFleet;
  format = pkgs.formats.json {};

  mkChannels = channels: requireMention:
    lib.listToAttrs (map (ch: {
      name = ch;
      value = {
        allow = true;
        requireMention = requireMention;
      };
    }) channels);

  mkBotConfig = b:
    let
      route = cfg.routing.${b};
      discordBase = {
        enabled = true;
        token = "__DISCORD_TOKEN__";
        dm = {
          enabled = cfg.discord.dm.enabled;
          policy = cfg.discord.dm.policy;
        };
        guilds = {
          "${cfg.guildId}" = {
            requireMention = route.requireMention;
            channels = mkChannels route.channels route.requireMention;
          };
        };
      };
      discordConfig = lib.recursiveUpdate discordBase cfg.discord.extraConfig;
    in {
      discord = discordConfig;
      routing = {
        queue = {
          mode = cfg.routingQueue.mode;
          byProvider = cfg.routingQueue.byProvider;
        };
      };
    };

  mkBotConfigFile = b: format.generate "clawdbot-${b}.json" (mkBotConfig b);

  mkBotSecret = b: {
    "discord_token_${b}" = {
      owner = "bot-${b}";
      group = "bot-${b}";
      mode = "0400";
    };
  };

  mkTemplate = b:
    let
      baseFile = mkBotConfigFile b;
      rawConfig = builtins.readFile baseFile;
      renderedConfig = builtins.replaceStrings [ "__DISCORD_TOKEN__" ] [ config.sops.placeholder."discord_token_${b}" ] rawConfig;
    in {
      "clawdbot-${b}.json" = {
        owner = "bot-${b}";
        group = "bot-${b}";
        mode = "0400";
        content = renderedConfig;
      };
    };

  mkBotUser = b: {
    name = "bot-${b}";
    value = {
      isSystemUser = true;
      group = "bot-${b}";
      home = "/var/lib/bot-${b}";
      createHome = true;
      shell = pkgs.bashInteractive;
    };
  };

  mkBotGroup = b: { name = "bot-${b}"; value = {}; };

  mkStateDir = b:
    let
      dir = "${cfg.stateDirBase}/${b}";
    in "d ${dir} 0700 bot-${b} bot-${b} - -";

  mkService = b:
    let
      stateDir = "${cfg.stateDirBase}/${b}";
      cfgPath = config.sops.templates."clawdbot-${b}.json".path;
      clawPkg = cfg.package;
    in {
      name = "clawdbot-${b}";
      value = {
        description = "Clawdbot Discord gateway (${b})";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" "sops-nix.service" ];
        wants = [ "network-online.target" "sops-nix.service" ];

        environment = {
          CLAWDBOT_NIX_MODE = "1";
          CLAWDBOT_STATE_DIR = stateDir;
          CLAWDBOT_CONFIG_PATH = cfgPath;
        };

        serviceConfig = {
          User = "bot-${b}";
          Group = "bot-${b}";
          WorkingDirectory = stateDir;

          ExecStart = "${clawPkg}/bin/clawdbot gateway";

          Restart = "always";
          RestartSec = "3";

          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ stateDir ];
          UMask = "0077";

          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
          SystemCallArchitectures = "native";
        };
      };
    };

  perBotSecrets = lib.mkMerge (map mkBotSecret cfg.bots);
  perBotTemplates = lib.mkMerge (map mkTemplate cfg.bots);
  wgSecret = {
    wg_private_key = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };
  wgIf = cfg.wireguard.interface;
  wgAddr = lib.head (lib.splitString "/" cfg.wireguard.address);
  sshListen = if cfg.bootstrapSsh then [ { addr = "0.0.0.0"; port = 22; } ] else [
    { addr = wgAddr; port = 22; }
    { addr = "127.0.0.1"; port = 22; }
  ];

in {
  options.services.clawdbotFleet = {
    enable = lib.mkEnableOption "Clawdbot fleet";

    package = lib.mkOption {
      type = lib.types.package;
      default = nix-clawdbot.packages.${pkgs.system}.clawdbot;
      description = "Clawdbot package used by fleet services.";
    };

    bots = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "maren" "sonja" "gunnar" "melinda" ];
      description = "Bot instance names (also used for system users).";
    };

    guildId = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Discord guild ID for routing.";
    };

    routing = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          channels = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Allowed Discord channels for this bot (slugged names).";
          };
          requireMention = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Require mention in allowed channels.";
          };
        };
      });
      default = {};
      description = "Per-bot routing rules.";
    };

    routingQueue = {
      mode = lib.mkOption {
        type = lib.types.enum [ "queue" "interrupt" ];
        default = "interrupt";
        description = "Queue mode when a run is active.";
      };
      byProvider = lib.mkOption {
        type = lib.types.attrs;
        default = { discord = "queue"; };
        description = "Per-provider queue mode overrides.";
      };
    };

    discord = {
      dm = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Discord DMs.";
        };
        policy = lib.mkOption {
          type = lib.types.enum [ "pairing" "allowlist" "open" "disabled" ];
          default = "disabled";
          description = "Discord DM policy.";
        };
      };

      extraConfig = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Extra Discord config merged into each bot config.";
      };
    };

    stateDirBase = lib.mkOption {
      type = lib.types.str;
      default = "/srv/clawdbot";
      description = "Base directory for per-bot state dirs.";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../secrets/bots01.yaml;
      description = "Sops file containing WireGuard key and bot tokens.";
    };

    sopsAgeKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sops-nix/key.txt";
      description = "Path to the age key on the host.";
    };

    bootstrapSsh = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow public SSH during initial bootstrap.";
    };

    wireguard = {
      interface = lib.mkOption {
        type = lib.types.str;
        default = "wg0";
        description = "WireGuard interface name.";
      };
      address = lib.mkOption {
        type = lib.types.str;
        default = "10.44.0.1/24";
        description = "WireGuard address for this host.";
      };
      listenPort = lib.mkOption {
        type = lib.types.port;
        default = 51820;
        description = "WireGuard UDP listen port.";
      };
      adminPeerPublicKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Admin peer public key (laptop).";
      };
      adminPeerAddress = lib.mkOption {
        type = lib.types.str;
        default = "10.44.0.2/32";
        description = "Admin peer allowed IPs.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.guildId != "";
        message = "services.clawdbotFleet.guildId must be set.";
      }
      {
        assertion = cfg.wireguard.adminPeerPublicKey != "";
        message = "services.clawdbotFleet.wireguard.adminPeerPublicKey must be set.";
      }
      {
        assertion = lib.all (b: lib.hasAttr b cfg.routing) cfg.bots;
        message = "services.clawdbotFleet.routing must define every bot in services.clawdbotFleet.bots.";
      }
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.efi.efiSysMountPoint = "/boot";

    services.qemuGuest.enable = true;

    services.openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AllowUsers = [ "admin" ];
      };
      listenAddresses = sshListen;
    };

    security.sudo.wheelNeedsPassword = true;

    networking.firewall = {
      enable = true;
      allowedUDPPorts = [ cfg.wireguard.listenPort ];
      allowedTCPPorts = lib.mkIf cfg.bootstrapSsh [ 22 ];
      interfaces.${wgIf}.allowedTCPPorts = lib.mkIf (!cfg.bootstrapSsh) [ 22 ];
    };

    networking.nftables.enable = true;
    networking.nftables.ruleset = builtins.readFile ../nftables/egress-block.nft;

    networking.wireguard.interfaces.${wgIf} = {
      ips = [ cfg.wireguard.address ];
      listenPort = cfg.wireguard.listenPort;
      privateKeyFile = config.sops.secrets.wg_private_key.path;

      peers = [
        {
          publicKey = cfg.wireguard.adminPeerPublicKey;
          allowedIPs = [ cfg.wireguard.adminPeerAddress ];
        }
      ];
    };

    sops = {
      defaultSopsFile = cfg.sopsFile;
      age.keyFile = cfg.sopsAgeKeyFile;
    };

    sops.secrets = lib.mkMerge [ wgSecret perBotSecrets ];
    sops.templates = perBotTemplates;

    users.users = builtins.listToAttrs (map mkBotUser cfg.bots);
    users.groups = builtins.listToAttrs (map mkBotGroup cfg.bots);

    systemd.tmpfiles.rules = map mkStateDir cfg.bots;

    environment.systemPackages = [ cfg.package pkgs.git pkgs.jq ];

    systemd.services = builtins.listToAttrs (map mkService cfg.bots);
  };
}
