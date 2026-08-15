#!/usr/bin/env bash
set -e

PLUGIN_ID="dorneles.omasaver"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
BINDINGS_CONFIG="$HOME/.config/hypr/bindings.lua"
MENU_CONFIG="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Omasaver for Omarchy..."

# 1. Ensure plugin is in place (symlink or copy)
mkdir -p "$HOME/.config/omarchy/plugins"
if [ "$SCRIPT_DIR" != "$PLUGIN_DIR" ]; then
  if [ -e "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_DIR"
  fi
  ln -s "$SCRIPT_DIR" "$PLUGIN_DIR" 2>/dev/null || cp -r "$SCRIPT_DIR" "$PLUGIN_DIR"
fi

# 2. Configure shell.json (add to plugins array, remove from bar.layout)
if [ -f "$SHELL_CONFIG" ]; then
  python3 - <<EOF
import json
import os

path = os.path.expanduser("$SHELL_CONFIG")
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}

# Ensure in plugins list (background overlay)
if "plugins" not in data or not isinstance(data["plugins"], list):
    data["plugins"] = []

found = any(isinstance(p, dict) and p.get("id") == "$PLUGIN_ID" for p in data["plugins"])
if not found:
    data["plugins"].append({"id": "$PLUGIN_ID"})

# Remove from bar layout if present
if "bar" in data and "layout" in data["bar"]:
    for section in ["left", "center", "right"]:
        if section in data["bar"]["layout"] and isinstance(data["bar"]["layout"][section], list):
            data["bar"]["layout"][section] = [
                item for item in data["bar"]["layout"][section]
                if not (isinstance(item, dict) and item.get("id") == "$PLUGIN_ID")
            ]

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
print("  ✓ Configured shell.json (overlay service, removed from top bar)")
EOF
fi

# 3. Add Hyprland keybinding
if [ -f "$BINDINGS_CONFIG" ]; then
  if ! grep -q "dorneles.omasaver" "$BINDINGS_CONFIG"; then
    cat <<'EOF' >> "$BINDINGS_CONFIG"

-- Omasaver Trigger
o.bind("SUPER + ALT + O", "Omasaver", "omarchy-shell dorneles.omasaver openStudio")
EOF
    echo "  ✓ Added keybinding to bindings.lua (Super+Alt+O)"
  fi
fi

# 4. Add Omarchy menu entries
if [ -f "$MENU_CONFIG" ]; then
  python3 - <<EOF
import os

path = os.path.expanduser("$MENU_CONFIG")
try:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    if "style.screensaver.omasaver" not in content:
        target = '"style.about"'
        entries = (
            '  "style.screensaver.omasaver": {"icon":"󱄄","label":"Omasaver (ASCII Art & Screensaver)","action":"omarchy-shell dorneles.omasaver openStudio","aliases":["omasaver","ascii art","screensaver"]},\n'
            '  "style.screensaver.preview": {"icon":"󱄄","label":"Pré-visualizar Omasaver","action":"omarchy-shell dorneles.omasaver preview","aliases":["testar screensaver","preview omasaver"]},\n'
        )
        if target in content:
            content = content.replace(target, entries + '  ' + target)
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            print("  ✓ Added menu entries to omarchy-menu.jsonc")
except Exception as e:
    pass
EOF
fi

# 5. Install python requirements
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
  pip install -q -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null || true
fi

# 6. Reload shell and Hyprland
if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi
if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
if command -v omarchy-restart-shell >/dev/null 2>&1; then
  omarchy-restart-shell >/dev/null 2>&1 || true
fi

echo "==> Omasaver installation complete!"
echo "    • Super+Alt+O : Open Omasaver modal"
