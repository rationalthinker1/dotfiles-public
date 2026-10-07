#!/usr/bin/env zsh
# ==============================================================================
# npm-native.zsh - Build the native addons in the npm GLOBAL prefixes
# ==============================================================================
# Defines `npm_native_rebuild [prefix…]`. With no argument it covers both prefixes
# that hold global installs here:
#   ${ZPFX}               zinit's polaris — graft (as'null' + npm --prefix, see .zshrc)
#   ${NPM_CONFIG_PREFIX}  plain `npm i -g`
#
# Sourced by: .zshrc, via the `${ZDOTDIR}/functions/`*.zsh(N) loop. Called by graft's
# atclone in .zshrc, by maintain phase 2 after `mise upgrade`, and by hand.
#
# THE FAILURE: "Error: No native build was found for platform=linux arch=x64
# runtime=node abi=137 … node=24.21.0". It reads like a node ABI mismatch and usually
# is not. npm 12 refuses every install-time lifecycle script not named in allow-scripts,
# so `npm install -g @nanonets/graft` lands tree-sitter-kotlin (no linux prebuild — it
# must compile) with no build/ dir at all. Reproduced on an unchanged node 24.21.0.
# Every `zi update` reinstalls graft (run-atpull), so any graft release re-breaks it.
#
# The ABI case is real too, but narrower: graft's grammars are all N-API today and
# loaded unchanged under node 26 (ABI 147). A NAN addon or an abi-tagged prebuild does
# break on a node major bump, and the same rebuild is the repair.
#
# THE ALLOWLIST is derived, not hardcoded, so a grammar graft adds later is covered. A
# package qualifies only if every lifecycle script it has is a native-build entry point
# (node-gyp-build, node-gyp rebuild, prebuild-install, node-pre-gyp install), or it has
# none and ships a binding.gyp (npm's implicit `node-gyp rebuild`). Anything else stays
# blocked — graft's own postinstall is a telemetry ping, tree-sitter-cli's downloads a
# binary graft does not need. Matching is on package.json `name`, which is what npm
# checks: graft's tree-sitter-r dir is really @davisvaughan/tree-sitter-r.
#
# Cheap when healthy: node-gyp-build's install step loads the existing build or
# prebuild first and only compiles when that fails. --allow-scripts on the command line
# REPLACES npmrc's allow-scripts for this call — harmless, it only narrows what runs.
# ==============================================================================

function npm_native_rebuild() {
    if ! (( $+commands[node] && $+commands[npm] )); then
        print -r -- "  node/npm not on PATH — nothing to rebuild"
        return 0
    fi

    local -a prefixes=( "$@" )
    (( ${#prefixes} )) || prefixes=( "${ZPFX}" "${NPM_CONFIG_PREFIX}" )

    # Walks node_modules recursively (scoped dirs included) and prints the name of every
    # package whose install-time scripts are purely a native build. Single-quoted for zsh,
    # so the JS uses double quotes only.
    local scan_js='
        const fs = require("fs"), path = require("path");
        const build = /^\s*(node-gyp-build|node-gyp rebuild|prebuild-install|node-pre-gyp install)(\s+--?[\w=.-]+)*\s*$/;
        const names = new Set();
        function scan(dir) {
            let ents;
            try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
            for (const e of ents) {
                if (!e.isDirectory() || e.name.startsWith(".")) continue;
                const p = path.join(dir, e.name);
                if (e.name.startsWith("@")) { scan(p); continue; }
                let pkg;
                try { pkg = JSON.parse(fs.readFileSync(path.join(p, "package.json"), "utf8")); } catch { continue; }
                const s = pkg.scripts || {};
                const hooks = ["preinstall", "install", "postinstall"].filter(k => s[k]);
                const native = hooks.length
                    ? hooks.every(k => s[k].split("||").every(c => build.test(c)))
                    : pkg.gypfile !== false && fs.existsSync(path.join(p, "binding.gyp"));
                if (native && pkg.name) names.add(pkg.name);
                scan(path.join(p, "node_modules"));
            }
        }
        scan(process.argv[1]);
        if (names.size) console.log([...names].join("\n"));
    '

    local prefix rc=0
    local -a allow
    # ${…:#} drops an unset ZPFX/NPM_CONFIG_PREFIX; (u) folds them if they coincide.
    for prefix in ${(u)prefixes:#}; do
        [[ -d "${prefix}/lib/node_modules" ]] || continue
        allow=( ${(f)"$(node -e "${scan_js}" "${prefix}/lib/node_modules")"} )
        if (( ! ${#allow} )); then
            print -r -- "  ✓ ${prefix}: no native addons to build"
            continue
        fi
        print -r -- "  ${prefix}: ${(j:, :)allow}"
        # --loglevel=error: the "N packages had install scripts blocked" warning is the
        # point of the allowlist, not a problem worth printing on every run.
        npm rebuild --global --prefix "${prefix}" --allow-scripts="${(j:,:)allow}" \
            --loglevel=error || rc=1
    done
    return ${rc}
}
