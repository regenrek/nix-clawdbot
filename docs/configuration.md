# Configuration

All configuration lives under `programs.clawdis`.

## Core

- `programs.clawdis.enable` (bool) — enable Clawdis
- `programs.clawdis.package` (package) — override package
- `programs.clawdis.stateDir` (string) — state directory (default: `~/.clawdis`)
- `programs.clawdis.workspaceDir` (string) — workspace directory
- `programs.clawdis.launchd.enable` (bool) — run gateway via launchd (macOS)

## Telegram (v1)

- `programs.clawdis.providers.telegram.enable` (bool)
- `programs.clawdis.providers.telegram.botTokenFile` (string)
- `programs.clawdis.providers.telegram.allowFrom` (list of int chat IDs)
- `programs.clawdis.providers.telegram.requireMention` (bool, default false)

## Routing

- `programs.clawdis.routing.queue.mode` — `queue` or `interrupt` (default: `interrupt`)
- `programs.clawdis.routing.queue.bySurface` — per-surface overrides
- `programs.clawdis.routing.groupChat.requireMention` — group activation default

## Example

```nix
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
```
