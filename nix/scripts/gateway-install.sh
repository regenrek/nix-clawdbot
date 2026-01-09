#!/bin/sh
set -e
mkdir -p "$out/lib/clawdbot" "$out/bin"

cp -r dist node_modules package.json ui "$out/lib/clawdbot/"

if [ -z "${STDENV_SETUP:-}" ]; then
  echo "STDENV_SETUP is not set" >&2
  exit 1
fi
if [ ! -f "$STDENV_SETUP" ]; then
  echo "STDENV_SETUP not found: $STDENV_SETUP" >&2
  exit 1
fi

bash -e -c '. "$STDENV_SETUP"; patchShebangs "$out/lib/clawdbot/node_modules/.bin"'
if [ -d "$out/lib/clawdbot/ui/node_modules/.bin" ]; then
  bash -e -c '. "$STDENV_SETUP"; patchShebangs "$out/lib/clawdbot/ui/node_modules/.bin"'
fi

# Work around missing dependency declaration in pi-coding-agent (strip-ansi).
# Ensure it is resolvable at runtime without changing upstream.
pi_pkg="$(find "$out/lib/clawdbot/node_modules/.pnpm" -path "*/node_modules/@mariozechner/pi-coding-agent" -print | head -n 1)"
if [ -n "$pi_pkg" ] && [ ! -e "$pi_pkg/node_modules/strip-ansi" ]; then
  if [ -d "$out/lib/clawdbot/node_modules/.pnpm/strip-ansi@7.1.2/node_modules/strip-ansi" ]; then
    strip_ansi_src="$out/lib/clawdbot/node_modules/.pnpm/strip-ansi@7.1.2/node_modules/strip-ansi"
  elif [ -d "$out/lib/clawdbot/node_modules/.pnpm/strip-ansi@6.0.1/node_modules/strip-ansi" ]; then
    strip_ansi_src="$out/lib/clawdbot/node_modules/.pnpm/strip-ansi@6.0.1/node_modules/strip-ansi"
  else
    strip_ansi_src=""
  fi

  if [ -n "$strip_ansi_src" ]; then
    mkdir -p "$pi_pkg/node_modules"
    ln -s "$strip_ansi_src" "$pi_pkg/node_modules/strip-ansi"
  fi
fi
bash -e -c '. "$STDENV_SETUP"; makeWrapper "$NODE_BIN" "$out/bin/clawdbot" --add-flags "$out/lib/clawdbot/dist/index.js" --set-default CLAWDBOT_NIX_MODE "1"'
