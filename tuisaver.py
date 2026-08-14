import argparse
import sys
import json
import os
import shutil
import subprocess
import pyfiglet
import pyperclip
from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Header, Footer, TextArea, Static, Select, Label, Button, Input
from textual.reactive import reactive
from rich.text import Text

CONFIG_DIR = os.path.expanduser("~/.config/tuisaver")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
SCREENSAVER_PATH = os.path.expanduser("~/.config/omarchy/branding/screensaver.txt")
ABOUT_PATH = os.path.expanduser("~/.config/omarchy/branding/about.txt")
OMARCHY_THEME_COLORS = os.path.expanduser("~/.local/state/omarchy/current/theme/colors.toml")
OMARCHY_DEFAULT_FONT = "delta_corps_priest_1"


def load_system_theme() -> dict:
    """Load the system theme from Omarchy if available, otherwise return empty dict."""
    if os.path.exists(OMARCHY_THEME_COLORS):
        try:
            import tomllib
            with open(OMARCHY_THEME_COLORS, "rb") as f:
                data = tomllib.load(f)
                return {
                    "bg": data.get("bg", data.get("background", "#0D1319")),
                    "panel_bg": data.get("lighter_bg", "#172532"),
                    "input_bg": data.get("darker_bg", "#070a0d"),
                    "fg": data.get("fg", data.get("foreground", "#F2ECCD")),
                    "muted": data.get("muted", data.get("dark_fg", "#7b8a8e")),
                    "accent": data.get("accent", data.get("blue", "#808b40")),
                    "primary": data.get("blue", data.get("accent", "#808b40")),
                    "secondary": data.get("magenta", data.get("green", "#dbc66f")),
                    "border": data.get("muted", "#7b8a8e"),
                }
        except Exception:
            pass
    return {}


def safe_save_file(path: str, content: str) -> None:
    """Save content to path safely with a single non-destructive backup."""
    target_path = os.path.expanduser(path)
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    bak_path = target_path + ".bak"
    if os.path.exists(target_path) and not os.path.exists(bak_path):
        shutil.copy2(target_path, bak_path)
    with open(target_path, "w", encoding="utf-8") as f:
        f.write(content)


def generate_ascii(text: str, font: str = "standard", h_layout: str = "default", align: str = "left") -> str:
    """Render ASCII art using PyFiglet with alignment and kerning support."""
    if not text.strip():
        return ""
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

    # Trim trailing whitespaces and normalize
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


class AsciiArtApp(App):
    TITLE = "TUIsaver"
    SUB_TITLE = "Modern ASCII Art Studio & Omarchy Hub"

    CSS = """
    Screen {
        background: $background;
        color: $text;
    }

    #sidebar {
        width: 48;
        height: 100%;
        background: $surface;
        border-right: heavy $primary;
        padding: 1 2;
        overflow-y: auto;
    }

    #canvas-container {
        height: 1fr;
        padding: 1 2;
        background: $background;
    }

    #ascii-frame {
        height: 1fr;
        border: double $accent;
        background: $background;
        overflow: auto auto;
        padding: 1;
        margin-bottom: 1;
    }

    #ascii-output {
        width: auto;
        text-wrap: nowrap;
        color: $accent;
    }

    .section-title {
        text-style: bold;
        color: $primary;
        margin-bottom: 1;
        text-align: center;
    }

    Label {
        color: $text-muted;
        margin-top: 1;
        width: 100%;
        text-style: bold;
    }

    TextArea, Select, Input {
        background: $panel;
        color: $text;
        border: none;
        width: 100%;
    }

    TextArea { height: 4; }
    Input { height: 3; padding: 0 1; margin-bottom: 1; }
    Select { height: 3; padding: 0 1; }

    TextArea:focus, Select:focus, Input:focus {
        background: $accent 25%;
        color: $text;
    }

    Select:disabled {
        opacity: 0.3;
        background: $surface;
    }

    .btn-preset {
        width: 100%;
        margin-top: 1;
        height: 3;
        text-style: bold;
        border: none;
        background: $primary;
        color: $text;
        content-align: center middle;
    }

    .btn-preset:focus, .btn-preset:hover {
        background: $accent;
        color: $background;
    }

    #button-bar {
        height: auto;
        align: center middle;
        padding: 0;
    }

    .btn-action {
        width: 1fr;
        min-width: 16;
        margin: 0 1;
        height: 3;
        text-style: bold;
        border: none;
        content-align: center middle;
    }

    #btn-copy { background: $primary; color: $text; }
    #btn-screensaver { background: $secondary; color: $text; }
    #btn-preview { background: $accent; color: $text; }
    #btn-about { background: $surface; color: $text; border: solid $primary; }

    .btn-action:focus {
        background: $accent;
        color: $background;
        text-style: bold italic;
    }

    #info-panel {
        margin-top: 1;
        padding: 1;
        background: $surface;
        color: $text-muted;
        text-align: center;
        height: auto;
        content-align: center middle;
        margin-bottom: 1;
    }
    """

    BINDINGS = [
        ("ctrl+c", "copy_to_clipboard", "Copy"),
        ("ctrl+s", "save_screensaver", "Screensaver"),
        ("ctrl+p", "preview_screensaver", "Preview"),
        ("ctrl+a", "save_about_logo", "About Logo"),
        ("ctrl+d", "select_delta_font", "Delta Font"),
        ("q", "quit", "Quit"),
    ]

    text = reactive("TUI\nsaver")
    font = reactive("standard")
    h_layout = reactive("default")
    align = reactive("left")

    def __init__(self, initial_text: str | None = None, initial_font: str | None = None, **kwargs):
        super().__init__(**kwargs)
        self.figlet_fonts = sorted(pyfiglet.FigletFont.getFonts())
        self.layout_options = [
            ("Default", "default"),
            ("Full", "full"),
            ("Fitted", "fitted"),
            ("Smushed", "smushed"),
        ]
        self.align_options = [
            ("Left", "left"),
            ("Center", "center"),
            ("Right", "right"),
        ]
        config = self.load_config()
        self.text = initial_text if initial_text is not None else config.get("text", "TUI\nsaver")
        self.font = initial_font if initial_font is not None else config.get("font", "standard")
        self.h_layout = config.get("h_layout", "default")
        self.align = config.get("align", "left")

    def load_config(self) -> dict:
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except (json.JSONDecodeError, OSError):
                return {}
        return {}

    def save_config(self) -> None:
        config = {
            "text": self.text,
            "font": self.font,
            "h_layout": self.h_layout,
            "align": self.align,
        }
        try:
            os.makedirs(CONFIG_DIR, exist_ok=True)
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(config, f, indent=2)
        except OSError:
            pass

    def render_current_ascii(self) -> str:
        return generate_ascii(
            text=self.text,
            font=self.font,
            h_layout=self.h_layout,
            align=self.align
        )

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical(id="sidebar"):
                yield Static("SETTINGS", classes="section-title")
                
                yield Label("Text (Max 3 lines)")
                yield TextArea(self.text, id="text-input", show_line_numbers=True, soft_wrap=False)
                
                yield Label("Search Font")
                yield Input(placeholder="Type to filter fonts...", id="font-search")

                yield Label("Font Style")
                yield Select([(f, f) for f in self.figlet_fonts], value=self.font, id="font-select", allow_blank=False)
                yield Button("⚡ Omarchy Font (Delta Corps)", id="btn-delta-font", classes="btn-preset")

                yield Label("Horizontal Kerning", id="label-h-kerning")
                yield Select(self.layout_options, value=self.h_layout, id="h-layout-select", allow_blank=False)
                
                yield Label("Alignment")
                yield Select(self.align_options, value=self.align, id="align-select", allow_blank=False)

                yield Static(id="info-panel")

            with Vertical(id="canvas-container"):
                with Container(id="ascii-frame"):
                    yield Static(id="ascii-output")
                
                with Horizontal(id="button-bar"):
                    yield Button("COPY\n(CTRL+C)", id="btn-copy", classes="btn-action")
                    yield Button("SCREENSAVER\n(CTRL+S)", id="btn-screensaver", classes="btn-action")
                    yield Button("PREVIEW\n(CTRL+P)", id="btn-preview", classes="btn-action")
                    yield Button("ABOUT LOGO\n(CTRL+A)", id="btn-about", classes="btn-action")
        yield Footer()

    def on_mount(self) -> None:
        self.query_one("#text-input").focus()
        self.apply_system_theme()
        self.check_font_support()
        self.update_ascii()

    def apply_system_theme(self) -> None:
        theme = load_system_theme()
        if not theme:
            return

        bg = theme.get("bg")
        panel_bg = theme.get("panel_bg")
        input_bg = theme.get("input_bg")
        fg = theme.get("fg")
        muted = theme.get("muted")
        accent = theme.get("accent")
        primary = theme.get("primary")
        secondary = theme.get("secondary")

        try:
            self.styles.background = bg
            self.styles.color = fg

            sidebar = self.query_one("#sidebar")
            sidebar.styles.background = panel_bg
            sidebar.styles.border_right = ("heavy", primary)

            frame = self.query_one("#ascii-frame")
            frame.styles.background = bg
            frame.styles.border = ("double", accent)

            canvas = self.query_one("#canvas-container")
            canvas.styles.background = bg

            for label in self.query("Label"):
                label.styles.color = muted
            for title in self.query(".section-title"):
                title.styles.color = primary
            for ctrl in self.query("TextArea, Select, Input"):
                ctrl.styles.background = input_bg
                ctrl.styles.color = fg

            self.query_one("#ascii-output").styles.color = accent

            if self.query("#btn-delta-font"):
                self.query_one("#btn-delta-font").styles.background = primary
                self.query_one("#btn-delta-font").styles.color = fg

            if self.query("#btn-copy"):
                self.query_one("#btn-copy").styles.background = primary
                self.query_one("#btn-copy").styles.color = fg
            if self.query("#btn-screensaver"):
                self.query_one("#btn-screensaver").styles.background = secondary
                self.query_one("#btn-screensaver").styles.color = fg
            if self.query("#btn-preview"):
                self.query_one("#btn-preview").styles.background = accent
                self.query_one("#btn-preview").styles.color = fg
            if self.query("#btn-about"):
                self.query_one("#btn-about").styles.background = panel_bg
                self.query_one("#btn-about").styles.color = fg

            info = self.query_one("#info-panel")
            info.styles.background = panel_bg
            info.styles.color = muted
        except Exception:
            pass

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "font-search":
            query = event.value.strip().lower()
            filtered = [f for f in self.figlet_fonts if query in f.lower()] if query else self.figlet_fonts
            select = self.query_one("#font-select", Select)
            if filtered:
                select.set_options([(f, f) for f in filtered])
                if self.font in filtered:
                    select.value = self.font
                else:
                    select.value = filtered[0]

    def on_text_area_changed(self, event: TextArea.Changed) -> None:
        if event.text_area.id == "text-input":
            lines = event.text_area.text.split("\n")
            if len(lines) > 3:
                event.text_area.text = "\n".join(lines[:3])
                event.text_area.move_cursor((2, len(lines[2])))
                self.notify("Max 3 lines allowed", severity="warning")
            self.text = event.text_area.text
            self.update_ascii()
            self.save_config()

    def on_select_changed(self, event: Select.Changed) -> None:
        if event.value is None or event.value == Select.BLANK:
            return
        if event.select.id == "font-select":
            self.font = str(event.value)
            self.check_font_support()
        elif event.select.id == "h-layout-select":
            self.h_layout = str(event.value)
        elif event.select.id == "align-select":
            self.align = str(event.value)
        self.update_ascii()
        self.save_config()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        btn_id = event.button.id
        if btn_id == "btn-copy":
            self.copy_result()
        elif btn_id == "btn-screensaver":
            self.save_to_screensaver()
        elif btn_id == "btn-preview":
            self.preview_screensaver()
        elif btn_id == "btn-about":
            self.save_to_about_logo()
        elif btn_id == "btn-delta-font":
            self.select_delta_font()

    def select_delta_font(self) -> None:
        if OMARCHY_DEFAULT_FONT in self.figlet_fonts:
            self.font = OMARCHY_DEFAULT_FONT
            search_input = self.query_one("#font-search", Input)
            if search_input.value:
                search_input.value = ""
            select = self.query_one("#font-select", Select)
            select.set_options([(f, f) for f in self.figlet_fonts])
            select.value = OMARCHY_DEFAULT_FONT
            self.check_font_support()
            self.update_ascii()
            self.save_config()
            self.notify(f"Font set to {OMARCHY_DEFAULT_FONT} (Omarchy Default)")

    def action_select_delta_font(self) -> None:
        self.select_delta_font()

    def check_font_support(self) -> None:
        try:
            f = pyfiglet.Figlet(font=self.font)
            supports_kerning = f.Font.smushMode != 64
            h_select = self.query_one("#h-layout-select", Select)
            h_label = self.query_one("#label-h-kerning", Label)
            h_select.disabled = not supports_kerning
            if not supports_kerning:
                h_label.update("Horizontal Kerning (N/A)")
                self.h_layout = "default"
            else:
                h_label.update("Horizontal Kerning")
        except Exception:
            pass

    def update_ascii(self) -> None:
        try:
            result = self.render_current_ascii()
            self.query_one("#ascii-output", Static).update(Text(result, no_wrap=True))
            lines = result.splitlines()
            h = len(lines)
            w = max((len(line) for line in lines), default=0)
            
            omarchy_status = "✨ Omarchy Theme Active" if os.path.exists(OMARCHY_THEME_COLORS) else "Terminal System Theme"
            self.query_one("#info-panel", Static).update(f"Canvas: {w}x{h} | Font: {self.font}\n{omarchy_status}")
        except Exception:
            pass

    def action_copy_to_clipboard(self) -> None:
        self.copy_result()

    def action_save_screensaver(self) -> None:
        self.save_to_screensaver()

    def action_preview_screensaver(self) -> None:
        self.preview_screensaver()

    def action_save_about_logo(self) -> None:
        self.save_to_about_logo()

    def copy_result(self) -> None:
        try:
            pyperclip.copy(self.render_current_ascii())
            self.notify("Art copied to clipboard!")
        except Exception as e:
            self.notify(f"Copy failed: {e}", severity="error")

    def save_to_screensaver(self) -> None:
        try:
            content = self.render_current_ascii()
            safe_save_file(SCREENSAVER_PATH, content)
            self.notify(f"Screensaver updated!\nSaved to {SCREENSAVER_PATH}")
        except Exception as e:
            self.notify(f"Save failed: {e}", severity="error")

    def save_to_about_logo(self) -> None:
        try:
            content = self.render_current_ascii()
            safe_save_file(ABOUT_PATH, content)
            self.notify(f"Omarchy about logo updated!\nSaved to {ABOUT_PATH}")
        except Exception as e:
            self.notify(f"Save failed: {e}", severity="error")

    def preview_screensaver(self) -> None:
        content = self.render_current_ascii()
        if not content.strip():
            self.notify("No text to preview!", severity="warning")
            return

        try:
            safe_save_file(SCREENSAVER_PATH, content)
        except Exception as e:
            self.notify(f"Could not prepare preview: {e}", severity="error")
            return

        if shutil.which("omarchy-launch-screensaver"):
            try:
                subprocess.Popen(
                    ["omarchy-launch-screensaver", "force"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                self.notify("Launching Omarchy screensaver preview...")
            except Exception as e:
                self.notify(f"Preview error: {e}", severity="error")
        elif shutil.which("ttfx"):
            try:
                term = shutil.which("xdg-terminal-exec") or shutil.which("foot") or shutil.which("alacritty") or shutil.which("ghostty") or shutil.which("kitty")
                if term:
                    subprocess.Popen(
                        [term, "-e", "bash", "-c", f"ttfx -i '{SCREENSAVER_PATH}' --random-effect; read -n1"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )
                    self.notify("Launching ttfx preview in terminal...")
                else:
                    self.notify("No terminal found to launch preview", severity="warning")
            except Exception as e:
                self.notify(f"Preview error: {e}", severity="error")
        else:
            self.notify("Screensaver preview requires Omarchy or ttfx", severity="warning")


def parse_args():
    parser = argparse.ArgumentParser(
        description="TUIsaver - Modern ASCII Art Studio & Omarchy Hub",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 tuisaver.py                             # Launch interactive TUI
  python3 tuisaver.py "OMARCHY" -d -s             # Save with delta_corps_priest_1 to screensaver
  python3 tuisaver.py "LOGO" -d --about           # Save with delta_corps_priest_1 to about.txt
  python3 tuisaver.py "HELLO" -a center -p        # Print centered art to stdout
  python3 tuisaver.py "MY PREVIEW" --preview      # Update screensaver and launch preview
  python3 tuisaver.py --list-fonts                # List all available FIGlet fonts
        """
    )
    parser.add_argument("text", nargs="?", default=None, help="Text to convert to ASCII art")
    parser.add_argument("-f", "--font", default="standard", help="FIGlet font name (default: standard)")
    parser.add_argument("-d", "--delta", action="store_true", help="Quickly use delta_corps_priest_1 font (Omarchy default)")
    parser.add_argument("-l", "--layout", choices=["default", "full", "fitted", "smushed"], default="default", help="Horizontal kerning layout")
    parser.add_argument("-a", "--align", choices=["left", "center", "right"], default="left", help="Text alignment")
    parser.add_argument("-s", "--screensaver", action="store_true", help="Save output to Omarchy screensaver path")
    parser.add_argument("--about", action="store_true", help="Save output to Omarchy branding about.txt path")
    parser.add_argument("-o", "--output", help="Save output to custom file path")
    parser.add_argument("-p", "--print", action="store_true", help="Print ASCII art to stdout and exit")
    parser.add_argument("--preview", action="store_true", help="Update screensaver and trigger Omarchy preview")
    parser.add_argument("--list-fonts", action="store_true", help="List all available FIGlet fonts")
    return parser.parse_args()


def main():
    args = parse_args()

    if args.list_fonts:
        fonts = sorted(pyfiglet.FigletFont.getFonts())
        print(f"Available FIGlet fonts ({len(fonts)} total):")
        for font in fonts:
            print(f"  {font}")
        sys.exit(0)

    # CLI mode if any action or text is explicitly passed
    if args.text is not None or args.screensaver or args.about or args.output or args.print or args.delta or args.preview:
        text = args.text if args.text is not None else "TUIsaver"
        selected_font = OMARCHY_DEFAULT_FONT if args.delta else args.font
        art = generate_ascii(text=text, font=selected_font, h_layout=args.layout, align=args.align)

        if args.print:
            print(art)

        if args.screensaver or args.preview:
            safe_save_file(SCREENSAVER_PATH, art)
            if not args.preview:
                print(f"✓ Saved to screensaver: {SCREENSAVER_PATH}")

        if args.about:
            safe_save_file(ABOUT_PATH, art)
            print(f"✓ Saved to about logo: {ABOUT_PATH}")

        if args.output:
            safe_save_file(args.output, art)
            print(f"✓ Saved to: {args.output}")

        if args.preview:
            print(f"✓ Updated screensaver with live preview and launching...")
            if shutil.which("omarchy-launch-screensaver"):
                subprocess.run(["omarchy-launch-screensaver", "force"])
            elif shutil.which("ttfx"):
                subprocess.run(["ttfx", "-i", SCREENSAVER_PATH, "--random-effect"])
            else:
                print("Warning: omarchy-launch-screensaver and ttfx not found.", file=sys.stderr)

        if not (args.print or args.screensaver or args.about or args.output or args.preview):
            print(art)
        sys.exit(0)

    # Otherwise, launch TUI Application
    app = AsciiArtApp()
    app.run()


if __name__ == "__main__":
    main()
