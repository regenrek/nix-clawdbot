{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, nodejs_22
, pnpm_10
, pkg-config
, jq
, python3
, node-gyp
, makeWrapper
, vips
, git
, zstd
, sourceInfo
, gatewaySrc ? null
, pnpmDepsHash ? "sha256-Y6+baewnub431IPE/gM7VHyevzp/AEjUJqLtNK25ztc="
}:

assert gatewaySrc == null || pnpmDepsHash != null;

let
  pnpmPlatform = if stdenv.hostPlatform.isDarwin then "darwin" else "linux";
  pnpmArch = if stdenv.hostPlatform.isAarch64 then "arm64" else "x64";
  nodeAddonApi = stdenv.mkDerivation {
    pname = "node-addon-api";
    version = "8.5.0";
    src = fetchurl {
      url = "https://registry.npmjs.org/node-addon-api/-/node-addon-api-8.5.0.tgz";
      hash = "sha256-0S8HyBYig7YhNVGFXx2o2sFiMxN0YpgwteZA8TDweRA=";
    };
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/node-addon-api
      tar -xf $src --strip-components=1 -C $out/lib/node_modules/node-addon-api
      runHook postInstall
    '';
  };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "clawdbot-gateway";
  version = "2026.1.5-3";

  src = if gatewaySrc != null then gatewaySrc else fetchFromGitHub sourceInfo;

  pnpmDeps = pnpm_10.fetchDeps {
    inherit (finalAttrs) pname version src;
    hash = if pnpmDepsHash != null
      then pnpmDepsHash
      else lib.fakeHash;
    fetcherVersion = 2;
    npm_config_arch = pnpmArch;
    npm_config_platform = pnpmPlatform;
    nativeBuildInputs = [ git ];
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm_10
    pkg-config
    jq
    python3
    node-gyp
    makeWrapper
    zstd
  ];

  buildInputs = [ vips ];

  env = {
    SHARP_IGNORE_GLOBAL_LIBVIPS = "1";
    npm_config_arch = pnpmArch;
    npm_config_platform = pnpmPlatform;
    PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS = "false";
    npm_config_nodedir = nodejs_22;
    npm_config_python = python3;
    NODE_PATH = "${nodeAddonApi}/lib/node_modules:${node-gyp}/lib/node_modules";
  };

  postPatch = ''
    if [ -f package.json ]; then
      "${../scripts/remove-package-manager-field.sh}" package.json
    fi
  '';

  preBuild = ''
    export HOME=$(mktemp -d)
    export STORE_PATH=$(mktemp -d)

    fetcherVersion=$(cat "${finalAttrs.pnpmDeps}/.fetcher-version" || echo 1)
    if [ "$fetcherVersion" -ge 3 ]; then
      tar --zstd -xf "${finalAttrs.pnpmDeps}/pnpm-store.tar.zst" -C "$STORE_PATH"
    else
      cp -Tr "${finalAttrs.pnpmDeps}" "$STORE_PATH"
    fi

    chmod -R +w "$STORE_PATH"

    # pnpm --ignore-scripts marks tarball deps as "not built" and offline install
    # later refuses to use them; if a dep doesn't require build, promote it.
    "${../scripts/promote-pnpm-integrity.sh}" "$STORE_PATH"

    pnpm config set store-dir "$STORE_PATH"
    pnpm config set package-import-method clone-or-copy
    pnpm config set manage-package-manager-versions false

    export REAL_NODE_GYP="$(command -v node-gyp)"
    wrapper_dir=$(mktemp -d)
    cat > "$wrapper_dir/node-gyp" <<'SH'
#!/bin/sh
if [ "$1" = "rebuild" ]; then
  shift
  "$REAL_NODE_GYP" configure "$@" && "$REAL_NODE_GYP" build "$@"
  exit $?
fi
exec "$REAL_NODE_GYP" "$@"
SH
    chmod +x "$wrapper_dir/node-gyp"
    export PATH="$wrapper_dir:$PATH"
  '';

  buildPhase = ''
    runHook preBuild
    pnpm install --offline --frozen-lockfile --ignore-scripts
    chmod -R u+w node_modules
    rm -rf node_modules/.pnpm/sharp@*/node_modules/sharp/src/build
    pnpm rebuild
    patchShebangs node_modules/{*,.*}
    pnpm build
    pnpm ui:build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/clawdbot $out/bin

    cp -r dist node_modules package.json ui $out/lib/clawdbot/

    makeWrapper ${nodejs_22}/bin/node $out/bin/clawdbot \
      --add-flags "$out/lib/clawdbot/dist/index.js" \
      --set-default CLAWDBOT_NIX_MODE "1"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Telegram-first AI gateway (Clawdbot)";
    homepage = "https://github.com/clawdbot/clawdbot";
    license = licenses.mit;
    platforms = platforms.darwin ++ platforms.linux;
    mainProgram = "clawdbot";
  };
})
