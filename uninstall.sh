#!/usr/bin/env bash
set -e

PLUGIN_ID="dorneles.omasaver"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
BINDINGS_CONFIG="$HOME/.config/hypr/bindings.lua"
MENU_CONFIG="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Uninstalling Omasaver..."

# 1. Revert shell.json configuration
if [ -f "$SHELL_CONFIG" ]; then
  python3 - <<EOF
import json
import os

path = os.path.expanduser("$SHELL_CONFIG")
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    changed = False
    if "plugins" in data and isinstance(data["plugins"], list):
        orig_len = len(data["plugins"])
        data["plugins"] = [
            p for p in data["plugins"]
            if not (isinstance(p, dict) and p.get("id") == "$PLUGIN_ID")
        ]
        if len(data["plugins"]) != orig_len:
            changed = True

    if "bar" in data and "layout" in data["bar"]:
        for section in ["left", "center", "right"]:
            if section in data["bar"]["layout"] and isinstance(data["bar"]["layout"][section], list):
                orig_len = len(data["bar"]["layout"][section])
                data["bar"]["layout"][section] = [
                    item for item in data["bar"]["layout"][section]
                    if not (isinstance(item, dict) and item.get("id") == "$PLUGIN_ID")
                ]
                if len(data["bar"]["layout"][section]) != orig_len:
                    changed = True

    if changed:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        print("  ✓ Removed plugin registration from shell.json")
    else:
        print("  ✓ shell.json is already clean")
except Exception as e:
    print(f"  ! Warning cleaning shell.json: {e}")
EOF
fi

# 2. Revert Hyprland keybinding from bindings.lua
if [ -f "$BINDINGS_CONFIG" ]; then
  python3 - <<EOF
import os
import re

path = os.path.expanduser("$BINDINGS_CONFIG")
try:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove delimited block if present
    new_content = re.sub(r'\n?-- BEGIN OMASAVER KEYBINDINGS[\s\S]*?-- END OMASAVER KEYBINDINGS\n?', '\n', content)
    
    # Remove any individual matching lines (including legacy un-delimited lines)
    lines = [
        line for line in new_content.splitlines()
        if "dorneles.omasaver" not in line and not ("SUPER + ALT + O" in line and "Omasaver" in line)
    ]
    cleaned = "\n".join(lines).strip() + "\n"

    if cleaned != content:
        with open(path, "w", encoding="utf-8") as f:
            f.write(cleaned)
        print("  ✓ Removed keybinding from bindings.lua")
    else:
        print("  ✓ bindings.lua is already clean")
except Exception as e:
    print(f"  ! Warning cleaning bindings.lua: {e}")
EOF
fi

# 3. Revert Omarchy menu entries from omarchy-menu.jsonc
if [ -f "$MENU_CONFIG" ]; then
  python3 - <<EOF
import os
import re

path = os.path.expanduser("$MENU_CONFIG")
try:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove delimited block if present
    new_content = re.sub(r'[ \t]*// BEGIN OMASAVER MENU[\s\S]*?// END OMASAVER MENU\n?', '', content)

    # Remove any individual matching lines
    lines = [
        line for line in new_content.splitlines()
        if not any(k in line for k in ["style.screensaver.omasaver", "style.screensaver.preview", "dorneles.omasaver"])
    ]
    cleaned = "\n".join(lines)

    if cleaned != content:
        with open(path, "w", encoding="utf-8") as f:
            f.write(cleaned)
        print("  ✓ Removed menu entries from omarchy-menu.jsonc")
    else:
        print("  ✓ omarchy-menu.jsonc is already clean")
except Exception as e:
    print(f"  ! Warning cleaning omarchy-menu.jsonc: {e}")
EOF
fi

# 4. Remove plugin directory and isolated virtual environment (.venv)
if [ -e "$PLUGIN_DIR" ]; then
  rm -rf "$PLUGIN_DIR"
  echo "  ✓ Removed plugin directory and isolated virtual environment: $PLUGIN_DIR"
fi

if [ "$SCRIPT_DIR" != "$PLUGIN_DIR" ] && [ -d "$SCRIPT_DIR/.venv" ]; then
  rm -rf "$SCRIPT_DIR/.venv"
  echo "  ✓ Removed local virtual environment: $SCRIPT_DIR/.venv"
fi

# 5. Reload shell and Hyprland
if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi
if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi
if command -v omarchy-restart-shell >/dev/null 2>&1; then
  omarchy-restart-shell >/dev/null 2>&1 || true
fi

echo "==> Omasaver uninstalled completely and system configuration cleaned successfully!"
