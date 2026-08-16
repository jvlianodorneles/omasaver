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

# Ensure executable permissions on scripts
chmod +x "$PLUGIN_DIR/scripts/omasaver-ctl.py" 2>/dev/null || true
chmod +x "$PLUGIN_DIR/install.sh" "$PLUGIN_DIR/uninstall.sh" 2>/dev/null || true

# 2. Set up isolated Python virtual environment with pinned dependencies
VENV_DIR="$PLUGIN_DIR/.venv"
REQ_FILE="$PLUGIN_DIR/requirements.txt"
if [ -f "$REQ_FILE" ]; then
  echo "  ==> Setting up isolated Python virtual environment..."
  if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
  fi
  "$VENV_DIR/bin/pip" install --require-virtualenv --no-cache-dir -q -r "$REQ_FILE"
  echo "  ✓ Installed pinned dependencies into isolated virtual environment (.venv)"
fi

# 3. Configure shell.json (add to plugins array, remove from bar.layout)
if [ -f "$SHELL_CONFIG" ]; then
  # Backup shell.json if backup does not already exist
  if [ ! -f "${SHELL_CONFIG}.bak" ]; then
    cp -p "$SHELL_CONFIG" "${SHELL_CONFIG}.bak"
  fi

  python3 - <<EOF
import json
import os

path = os.path.expanduser("$SHELL_CONFIG")
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}

# Ensure in plugins list (background overlay service)
if "plugins" not in data or not isinstance(data["plugins"], list):
    data["plugins"] = []

found = any(isinstance(p, dict) and p.get("id") == "$PLUGIN_ID" for p in data["plugins"])
if not found:
    data["plugins"].append({"id": "$PLUGIN_ID"})

# Remove from top bar layout if present
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

# 4. Add Hyprland keybinding
if [ -f "$BINDINGS_CONFIG" ]; then
  # Backup bindings.lua if backup does not already exist
  if [ ! -f "${BINDINGS_CONFIG}.bak" ]; then
    cp -p "$BINDINGS_CONFIG" "${BINDINGS_CONFIG}.bak"
  fi

  python3 - <<EOF
import os
import re

path = os.path.expanduser("$BINDINGS_CONFIG")
try:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if "dorneles.omasaver" not in content:
        binding_block = (
            "\n-- BEGIN OMASAVER KEYBINDINGS\n"
            "o.bind(\"SUPER + ALT + O\", \"Omasaver\", \"omarchy-shell dorneles.omasaver openStudio\")\n"
            "-- END OMASAVER KEYBINDINGS\n"
        )
        with open(path, "w", encoding="utf-8") as f:
            f.write(content.rstrip() + "\n" + binding_block)
        print("  ✓ Added keybinding to bindings.lua (Super+Alt+O)")
    else:
        print("  ✓ Keybinding already present in bindings.lua")
except Exception as e:
    print(f"  ! Warning configuring bindings.lua: {e}")
EOF
fi

# 5. Add Omarchy menu entries
if [ -f "$MENU_CONFIG" ]; then
  # Backup omarchy-menu.jsonc if backup does not already exist
  if [ ! -f "${MENU_CONFIG}.bak" ]; then
    cp -p "$MENU_CONFIG" "${MENU_CONFIG}.bak"
  fi

  python3 - <<EOF
import os

path = os.path.expanduser("$MENU_CONFIG")
try:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if "style.screensaver.omasaver" not in content:
        target = '"style.about"'
        entries = (
            '  // BEGIN OMASAVER MENU\n'
            '  "style.screensaver.omasaver": {"icon":"󱄄","label":"Omasaver (ASCII Art & Screensaver)","action":"omarchy-shell dorneles.omasaver openStudio","aliases":["omasaver","ascii art","screensaver"]},\n'
            '  "style.screensaver.preview": {"icon":"󱄄","label":"Pré-visualizar Omasaver","action":"omarchy-shell dorneles.omasaver preview","aliases":["testar screensaver","preview omasaver"]},\n'
            '  // END OMASAVER MENU\n'
        )
        if target in content:
            content = content.replace(target, entries + '  ' + target)
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            print("  ✓ Added menu entries to omarchy-menu.jsonc")
        else:
            print("  ! Target marker not found in omarchy-menu.jsonc, skipping menu injection")
    else:
        print("  ✓ Menu entries already present in omarchy-menu.jsonc")
except Exception as e:
    print(f"  ! Warning configuring omarchy-menu.jsonc: {e}")
EOF
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
