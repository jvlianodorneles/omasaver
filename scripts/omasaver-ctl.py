#!/usr/bin/env python3
import sys
import os
import json
import time
import shutil
import subprocess

# Auto-detect local virtual environment (.venv) site-packages if present
_script_dir = os.path.dirname(os.path.realpath(__file__))
_plugin_dir = os.path.dirname(_script_dir)
_venv_dir = os.path.join(_plugin_dir, ".venv")
if os.path.isdir(_venv_dir):
    import glob
    for _site_pkg in glob.glob(os.path.join(_venv_dir, "lib", "python*", "site-packages")):
        if _site_pkg not in sys.path:
            sys.path.insert(0, _site_pkg)

try:
    import pyfiglet
except ImportError:
    pyfiglet = None

try:
    import pyperclip
except ImportError:
    pyperclip = None

SCREENSAVER_PATH = os.path.expanduser("~/.config/omarchy/branding/screensaver.txt")
ABOUT_PATH = os.path.expanduser("~/.config/omarchy/branding/about.txt")
DEFAULT_FONT = "delta_corps_priest_1"

POPULAR_FONTS = [
    "delta_corps_priest_1",
    "standard",
    "slant",
    "banner",
    "block",
    "doom",
    "epic",
    "starwars",
    "isometric1",
    "alligator",
    "graffiti",
    "speed",
    "sub-zero",
    "cyberlarge",
    "larry3d",
    "shadow",
    "ogre",
    "colossal",
    "cosmic",
    "caligraphy",
]


def safe_save_file(path: str, content: str) -> None:
    target_path = os.path.expanduser(path)
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    bak_path = target_path + ".bak"
    if os.path.exists(target_path) and not os.path.exists(bak_path):
        shutil.copy2(target_path, bak_path)
    with open(target_path, "w", encoding="utf-8") as f:
        f.write(content)


def generate_ascii(text: str, font: str = DEFAULT_FONT, h_layout: str = "default", align: str = "left") -> str:
    if not text.strip():
        return ""
    if pyfiglet is None:
        return text

    try:
        f = pyfiglet.Figlet(font=font, width=2000)
        if h_layout == "full":
            f.Font.smushMode = -1
        elif h_layout == "fitted":
            f.Font.smushMode = 1
        elif h_layout == "smushed":
            f.Font.smushMode = 2
        raw_result = f.renderText(text)
    except Exception:
        f = pyfiglet.Figlet(font="standard", width=2000)
        raw_result = f.renderText(text)

    lines = [line.rstrip() for line in raw_result.split("\n")]
    while lines and not lines[-1]:
        lines.pop()

    max_len = max((len(l) for l in lines), default=0)
    if max_len == 0 or align == "left":
        return "\n".join(lines)

    aligned = []
    for line in lines:
        if align == "center":
            spaces = (max_len - len(line)) // 2
            aligned.append(" " * spaces + line)
        elif align == "right":
            spaces = max_len - len(line)
            aligned.append(" " * spaces + line)
        else:
            aligned.append(line)

    return "\n".join(aligned)


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command provided"}))
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "list-fonts":
        all_fonts = sorted(pyfiglet.FigletFont.getFonts()) if pyfiglet else POPULAR_FONTS
        print(json.dumps({"popular": POPULAR_FONTS, "all": all_fonts}))
        sys.exit(0)

    if cmd == "read-screensaver":
        if os.path.exists(SCREENSAVER_PATH):
            try:
                with open(SCREENSAVER_PATH, "r", encoding="utf-8") as f:
                    print(f.read())
            except Exception as e:
                print(f"Error reading screensaver: {e}")
        else:
            print("")
        sys.exit(0)

    if cmd == "read-about":
        if os.path.exists(ABOUT_PATH):
            try:
                with open(ABOUT_PATH, "r", encoding="utf-8") as f:
                    print(f.read())
            except Exception as e:
                print(f"Error reading about: {e}")
        else:
            print("")
        sys.exit(0)

    if cmd == "restore-defaults":
        omarchy_path = os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")
        # Restore screensaver
        default_screensaver = os.path.join(omarchy_path, "logo.txt")
        if os.path.exists(default_screensaver):
            with open(default_screensaver, "r", encoding="utf-8") as f:
                safe_save_file(SCREENSAVER_PATH, f.read())
        elif os.path.exists(SCREENSAVER_PATH + ".bak"):
            shutil.copy2(SCREENSAVER_PATH + ".bak", SCREENSAVER_PATH)

        # Restore about logo
        default_about = os.path.join(omarchy_path, "icon.txt")
        if os.path.exists(default_about):
            with open(default_about, "r", encoding="utf-8") as f:
                safe_save_file(ABOUT_PATH, f.read())
        elif os.path.exists(ABOUT_PATH + ".bak"):
            shutil.copy2(ABOUT_PATH + ".bak", ABOUT_PATH)

        print(json.dumps({"success": True, "restored": True}))
        sys.exit(0)

    # Rendering commands
    text = sys.argv[2] if len(sys.argv) > 2 else "OMARCHY"
    font = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_FONT
    align = sys.argv[4] if len(sys.argv) > 4 else "left"
    layout = sys.argv[5] if len(sys.argv) > 5 else "default"

    art = generate_ascii(text=text, font=font, h_layout=layout, align=align)

    if cmd == "render":
        print(art)
        sys.exit(0)

    elif cmd == "save-screensaver":
        safe_save_file(SCREENSAVER_PATH, art)
        print(json.dumps({"success": True, "path": SCREENSAVER_PATH}))
        sys.exit(0)

    elif cmd == "save-about":
        safe_save_file(ABOUT_PATH, art)
        print(json.dumps({"success": True, "path": ABOUT_PATH}))
        sys.exit(0)

    elif cmd == "copy":
        if pyperclip:
            pyperclip.copy(art)
            print(json.dumps({"success": True}))
        else:
            p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
            p.communicate(art.encode("utf-8"))
            print(json.dumps({"success": True}))
        sys.exit(0)

    elif cmd == "preview":
        safe_save_file(SCREENSAVER_PATH, art)
        if shutil.which("omarchy-launch-screensaver"):
            proc = subprocess.Popen(["omarchy-launch-screensaver", "force"])
            proc.wait()
            # Give a brief moment for the screensaver windows to map
            time.sleep(0.4)
            # Wait while screensaver is active
            while True:
                res = subprocess.run(["pgrep", "-f", "[o]rg.omarchy.screensaver"], stdout=subprocess.DEVNULL)
                if res.returncode != 0:
                    break
                time.sleep(0.25)
            print(json.dumps({"success": True, "preview_ended": True}))
        elif shutil.which("ttfx"):
            proc = subprocess.Popen(["ttfx", "-i", SCREENSAVER_PATH, "--random-effect"])
            proc.wait()
            print(json.dumps({"success": True, "preview_ended": True}))
        else:
            print(json.dumps({"success": True, "launched": False, "warning": "omarchy-launch-screensaver not found"}))
        sys.exit(0)

    print(json.dumps({"error": f"Unknown command: {cmd}"}))


if __name__ == "__main__":
    main()
