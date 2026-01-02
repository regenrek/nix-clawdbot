# Quickstart: Telegram (macOS)

This is the fastest path to a working Clawdis bot.

## 1) Add nix-clawdis to your flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-clawdis.url = "github:joshp123/nix-clawdis";
  };
}
```

## 2) Enable the module

```nix
{
  homeManagerConfigurations.josh = home-manager.lib.homeManagerConfiguration {
    pkgs = import nixpkgs { system = "aarch64-darwin"; };
    modules = [
      nix-clawdis.homeManagerModules.clawdis
      {
        programs.clawdis = {
          enable = true;
          providers.telegram = {
            enable = true;
            botTokenFile = "/run/agenix/telegram-bot-token";
            allowFrom = [ 12345678 -1001234567890 ];
          };
          routing.queue.mode = "interrupt";
        };
      }
    ];
  };
}
```

## 3) Apply

```bash
home-manager switch --flake .#josh
```

## 4) Verify

```bash
nix run .#clawdis -- status
nix run .#clawdis -- health
```

If both commands are OK, you’re done.
