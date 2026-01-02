# RFC: Declarative Clawdis as a Nix Package (nix-clawdis)

- Date: 2026-01-02
- Status: Implementing
- Audience: Nix users, agents (Codex/Claude), package maintainers, operators

## 1) Narrative: what we are building and why

Clawdis is powerful but hard to install and configure for new users, especially those who do not want to learn Nix internals. We need a batteries-included, obvious, and safe path to get a working Clawdis instance with minimal friction. This RFC proposes a dedicated public repo, `nix-clawdis`, that packages Clawdis for Nix and provides a declarative, user-friendly configuration layer with strong defaults, clear examples, and an agent-friendly onboarding flow.

The goal is to make Clawdis installation and configuration feel as simple as: add a flake input, enable a module, paste tokens, and run a single build. The output should be deterministic, secure by default, and easy to troubleshoot.

## 1.1) Non-negotiables

- Nix-first installation: no global installs, no manual brew steps required for core functionality.
- Safe defaults: providers disabled unless explicitly enabled and configured.
- No secrets committed to the repo; clear guidance for secrets injection (agenix, env vars, files).
- Obvious, copy-pasteable configuration examples.
- Deterministic builds and reproducible outputs.
- Documentation must be suitable for publication on the internet.

## 2) Goals / Non-goals

Goals:
- Provide a Nix package for Clawdis and a Home Manager module with batteries-included defaults.
- Provide a flake app and CLI entrypoint for quick start and health checks.
- Make configuration technically light with explicit options and guardrails.
- Provide Telegram-first examples and workflows.
- Provide clear troubleshooting and a minimal verification checklist.
- New user can get a working bot in 10 minutes without understanding Nix internals.

Non-goals:
- Rewriting Clawdis core functionality.
- Supporting non-Nix install paths in this repo.
- Shipping a hosted SaaS or paid hosting.
- Replacing upstream Clawdis docs.
- Cross-platform support (Linux/Windows) in v1.
- CI automation in v1.

## 3) System overview

`nix-clawdis` is a public repo that provides (macOS-only in v1, no CI in v1):
- A Nix package derivation for Clawdis.
- A Home Manager module for user-level config and service wiring.
- A nix-darwin module for macOS users (optional, thin wrapper over HM).
- A flake with devShell + example configs + minimal CLI apps.
- Documentation and examples optimized for new users and agents.

## 4) Components and responsibilities

- **Package derivation**: builds Clawdis from a pinned source (tag or rev) and exposes a binary.
- **Home Manager module**: declarative config, writes `~/.clawdis/clawdis.json`, manages services.
- **Flake outputs**:
  - `packages.<system>.clawdis` (binary)
  - `apps.<system>.clawdis` (CLI)
  - `apps.<system>.clawdis-setup` (guided setup -> emits Nix snippet)
  - `apps.<system>.clawdis-doctor` (health + config validation)
  - `devShells.<system>.default` (docs + lint + tests)
  - `homeManagerModules.clawdis`
  - `darwinModules.clawdis` (if needed)
- **Docs + examples**: Quick start, minimal config, provider-specific guides, troubleshooting.

### 4.1) Module option schema (proposed)

Top-level options (Home Manager):
- `programs.clawdis.enable` (bool, default false)
- `programs.clawdis.package` (package, default `pkgs.clawdis`)
- `programs.clawdis.config` (attrset -> rendered to `~/.clawdis/clawdis.json`)
- `programs.clawdis.providers.telegram.enable` (bool, default false)
- `programs.clawdis.providers.telegram.botTokenFile` (path, required if enabled)
- `programs.clawdis.providers.telegram.allowFrom` (list of chat IDs, required if enabled)
- `programs.clawdis.providers.whatsapp.enable` (bool, default false)
- `programs.clawdis.providers.whatsapp.web.enabled` (bool, default false)
- `programs.clawdis.routing.queue.mode` (enum: queue|interrupt, default interrupt)
- `programs.clawdis.routing.queue.bySurface` (attrset)
- `programs.clawdis.health.enable` (bool, default true)

Defaults:
- All providers disabled.
- Queue mode defaults to interrupt for Telegram/WhatsApp, queue for Discord/WebChat.
- No allowlist means no replies in direct chats.

### 4.2) Tradeoffs (why this design)

- **Safe defaults vs. zero-friction**: default-off providers reduce risk but require explicit config. We accept the extra step for safety and clarity.
- **Home Manager first**: HM is the clearest UX for user config, but NixOS-only users must adopt HM or a thin wrapper module.
- **Guided setup wizard**: adds maintenance overhead, but it is the fastest path for non-Nix users.

## 5) Inputs / workflow profiles

Minimum inputs (new user):
- Nix with flakes enabled.
- One provider token (Telegram or WhatsApp/web login).
- A minimal config snippet.

Workflow profiles (Telegram-first):
1) **Telegram-only quick start**
   - Enable module
   - Provide bot token
   - Add allowFrom chat IDs
   - Run build
2) **WhatsApp/web**
   - Enable module
   - Run QR login helper
   - Verify status
3) **Multi-provider**
   - Telegram + WhatsApp enabled
   - Separate allowlists
   - Verify routing

Validation rules:
- Config must pass schema validation before the service starts.
- Providers must not start unless explicitly enabled and configured.
- Health command must return configured and provider status.

### 5.1) Example configs (inline, required)

Telegram minimal (opinionated defaults):

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

Telegram + WhatsApp (batteries-included workflow):

```nix
{
  programs.clawdis = {
    enable = true;
    providers = {
      telegram = {
        enable = true;
        botTokenFile = "/run/agenix/telegram-bot-token";
        allowFrom = [ 12345678 -1001234567890 ];
      };
      whatsapp = {
        enable = true;
        web.enabled = true;
      };
    };
    routing.queue = {
      mode = "interrupt";
      bySurface = {
        telegram = "interrupt";
        whatsapp = "interrupt";
        discord = "queue";
        webchat = "queue";
      };
    };
  };
}
```

## 6) Artifacts / outputs

- `clawdis` binary in PATH.
- Declarative `~/.clawdis/clawdis.json` (generated).
- `clawdis status` and `clawdis health` outputs for verification.
- Example configs inline in the RFC (Telegram-first, WhatsApp optional).

## 7) State machine (if applicable)

Not applicable. (Packaging + configuration RFC.)

## 8) API surface (protobuf)

None. This RFC does not introduce new protobuf APIs.

## 9) Interaction model

Users interact via:
- Nix config (flake + module options)
- CLI (`clawdis status`, `clawdis health`, `clawdis send`)
- Provider-specific setup steps (Telegram token, WhatsApp QR)

Agent-friendly flow:
- Docs include a “copy-paste config” section with clear placeholders.
- A guided troubleshooting checklist with exact commands and expected output.
- `nix run nix-clawdis#clawdis-setup` produces a minimal Nix snippet from a short prompt flow.

### 9.1) Guided setup UX contract (clawdis-setup)

The wizard must:
- Ask only for provider selection, tokens/file paths, and allowlist IDs.
- Output a complete Nix snippet ready to paste into a flake or HM config.
- Never print secrets to stdout unless explicitly confirmed.
- End with a one-line “next command to run” (build + health check).

### 9.2) Zero to Clawdis (no-Nix user path)

The public docs must include a step-by-step “Zero to Clawdis” guide that covers:
1) Install Determinate Nix on macOS (copy/paste command + link).
2) Enable flakes and basic Nix config.
3) Create a minimal flake (template).
4) Add `nix-clawdis` input and HM module.
5) Paste minimal config snippet (Telegram or WhatsApp).
6) Run build and verify with `clawdis status` / `clawdis health`.

### 9.3) Agent copypasta (Codex/Claude)

Provide a single prompt users can paste into a coding agent that results in:
- Determinate Nix installed (if missing).
- A local flake scaffold created.
- `nix-clawdis` added as an input.
- A minimal Clawdis config generated with batteries‑included defaults (Telegram-first).
- A final “run these commands” section.

## 10) System interaction diagram

```
User -> Nix flake config -> HM module -> ~/.clawdis/clawdis.json
User -> nix run .#clawdis (CLI) -> gateway/service -> providers
Providers -> Clawdis -> responses to chat
```

## 11) API call flow (detailed)

Not applicable (no new APIs). Primary flows are CLI and provider interactions.

## 12) Determinism and validation

- Pin Clawdis source to a known revision or release tag.
- Schema validation required for generated config.
- Refuse to start provider services without required tokens/credentials.
- Strict allowlists for inbound chat IDs.
- Emit clear, actionable error messages when config is invalid.

## 13) Outputs and materialization

- Primary output: working Clawdis instance configured via Nix.
- Docs output: README + Quick Start + Troubleshooting.
- Example configs embedded in the RFC.

Docs structure (public-facing):
- `README.md` (30-second quick start + install matrix)
- `docs/quickstart-telegram.md`
- `docs/quickstart-whatsapp.md`
- `docs/configuration.md` (all options, defaults, and examples)
- `docs/troubleshooting.md` (copy-paste commands + expected outputs)
- `docs/zero-to-clawdis.md` (Determinate Nix install + macOS bootstrap path)
- `docs/agent-copypasta.md` (copy/paste prompt for Codex/Claude)

## 14) Testing philosophy and trust

- Build derivation test: Nix build must succeed on macOS (v1).
- Smoke test: `clawdis status` and `clawdis health` output.
- Provider tests: Telegram token presence and minimal send test (documented).
- No CI in v1 (manual validation checklist only).

## 15) Incremental delivery plan

1) Repo scaffold with flake, package derivation, minimal docs.
2) Home Manager module with basic config generation and safe defaults.
3) Telegram quick start and example config.
4) WhatsApp/web quick start and example config.
5) Troubleshooting guide + FAQ.
6) Public release and announcement.

### 15.1) Rollout / rollback

- Rollout: publish repo and pin a release tag; users pin via flake input.
- Rollback: document how to pin to a prior tag and revert module options.

## 16) Implementation order

1) Create `nix-clawdis` repo structure and flake.
2) Implement package derivation (pin Clawdis source).
3) Implement HM module with schema validation and config generation.
4) Add CLI apps (`clawdis`, `clawdis status`, `clawdis health`).
5) Add examples + docs (README + quickstarts + troubleshooting).
6) Add CI for build + formatting + docs checks.

## 17) Brutal self-review (required)

Findings (by persona):
- Junior engineer: Needed a concrete “wizard contract” and copy‑paste snippet. Added 9.1 + example config.
- Mid-level engineer: Lacked explicit module option schema and defaults. Added 4.1 + defaults.
- Senior/principal engineer: Missing tradeoff framing and rollback plan. Added 4.2 + 15.1.
- PM: Success criteria needed to be explicit. Added 10‑minute onboarding goal in section 2.
- EM: Delivery plan was fine, but rollback not stated; now explicit.
- External stakeholder: Narrative needed clearer public framing; kept non‑negotiables and internet‑safe doc requirements.
- End user: Needed a technically light path with clear next command; added 9.1 + 9.2 to require that output.

Open gaps (must resolve before “Reviewed”):
- WhatsApp/web QR flow still described but not specified (command + output).
- `clawdis-setup` wizard is stub-only.

Second pass review (delta):
- Tightened language to “technically light” and made Telegram-first explicit.
- Made macOS-only + no-CI explicit in goals/non-goals and testing.
- Moved examples into inline RFC blocks to keep the document self-contained.
- Added Zero-to-Clawdis + Agent Copypasta requirements as first-class docs.

## 18) Implementation status (current)

Implemented in `nix-clawdis` repo:
- Flake outputs: package + apps + devShell + HM module + darwin wrapper
- Clawdis gateway package pinned to `d4ee40db53a1d00b448a1153f2be58007213110f`
- Telegram-first HM module (launchd on macOS)
- README + Zero-to-Clawdis + Agent Copypasta + Quickstart/Config/Troubleshooting docs

Remaining:
- Replace `clawdis-setup` stub with real guided flow
- Validate pnpmDeps hash against current pin
- Add WhatsApp quickstart once Telegram path is verified
