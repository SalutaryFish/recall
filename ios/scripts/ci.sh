#!/usr/bin/env bash
# Helpers for .github/workflows/ios.yml (run from ios/).
set -euo pipefail

case "${1:-}" in
    install-xcodegen)
        # Pinned release binary; Homebrew as a fallback.
        version="${XCODEGEN_VERSION:?}"
        dest="$HOME/.local/xcodegen-$version"
        if [[ ! -x "$dest/bin/xcodegen" ]]; then
            tmp="$(mktemp -d)"
            if curl -fsSL -o "$tmp/xcodegen.zip" \
                "https://github.com/yonaskolb/XcodeGen/releases/download/$version/xcodegen.zip"; then
                unzip -q "$tmp/xcodegen.zip" -d "$tmp"
                mkdir -p "$dest"
                cp -R "$tmp/xcodegen/." "$dest/"
            else
                HOMEBREW_NO_AUTO_UPDATE=1 brew install xcodegen
                mkdir -p "$dest/bin"
                ln -sf "$(command -v xcodegen)" "$dest/bin/xcodegen"
            fi
        fi
        echo "$dest/bin" >> "$GITHUB_PATH"
        ;;
    simulator)
        # Newest available iOS runtime; prefer the iPhone the prototype was drawn for.
        list="$(mktemp)"
        xcrun simctl list devices available -j > "$list"
        python3 - "$list" <<'PY'
import json, re, sys
devices = json.load(open(sys.argv[1]))["devices"]
def version(runtime):
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)
ios = sorted((r for r in devices if "iOS" in r and devices[r]), key=version)
phones = [d for d in devices[ios[-1]] if d["name"].startswith("iPhone")]
preferred = [d for d in phones if d["name"] in ("iPhone 17 Pro", "iPhone 18 Pro", "iPhone 16 Pro")]
pick = (preferred or phones)[0]
print(pick["udid"])
print("simulator:", pick["name"], "on", ios[-1].split(".")[-1], file=sys.stderr)
PY
        ;;
    *)
        echo "usage: ci.sh install-xcodegen|simulator" >&2
        exit 2
        ;;
esac
