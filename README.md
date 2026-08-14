# 🎨 Omasaver

> **A native Omarchy 4 bar widget and studio for live ASCII art generation, screensaver management (`ttfx`), and branding customization.**

`omasaver` transforms text into beautiful ASCII art instantly, integrating seamlessly into your Omarchy 4 desktop workflow and top bar. Easily generate, customize, test, and sync your ASCII art across your Omarchy screensaver (`screensaver.txt`) and system about branding (`about.txt`).

---

## ✨ Features

- **🚀 Top Bar Widget:** Quick-access widget on your Omarchy bar with real-time ASCII status.
- **⚡ Interactive Studio Popup:**
  - Instant live ASCII rendering as you type.
  - One-click font presets including Omarchy's signature `delta_corps_priest_1`, `slant`, `banner`, `doom`, `starwars`, and more.
  - Monospaced, scrollable live preview box.
- **👁️ Live Screensaver Preview:** Test the `ttfx` screensaver animation in full screen with one click.
- **💾 1-Click Branding Sync:**
  - Update `~/.config/omarchy/branding/screensaver.txt` with automatic backup.
  - Update `~/.config/omarchy/branding/about.txt` (Fastfetch/Logo).
- **📋 Clipboard Integration:** Instantly copy generated ASCII art to clipboard (`wl-copy` / `pyperclip`).
- **🖥️ Standalone Terminal Studio:** Launch the full interactive Textual TUI studio directly from the widget or terminal.
- **🛠️ Automation CLI:** Fully scriptable backend CLI for shell scripts and system hooks.

---

## 📦 Installation

### Option 1: Via Omarchy Plugin Manager (Recommended)

```bash
omarchy plugin add https://github.com/jvlianodorneles/omasaver.git --enable --yes
```

### Option 2: Manual Installation

1. Clone into your Omarchy plugins directory:
   ```bash
   git clone https://github.com/jvlianodorneles/omasaver.git ~/.config/omarchy/plugins/dorneles.omasaver
   ```

2. Rescan and enable the plugin in Omarchy:
   ```bash
   omarchy-shell shell rescanPlugins
   omarchy plugin enable dorneles.omasaver
   ```

3. (Optional) Install Python dependencies for the full terminal TUI:
   ```bash
   pip install -r ~/.config/omarchy/plugins/dorneles.omasaver/requirements.txt
   ```

---

## 🎮 Quick Controls

| Action | Control |
| :--- | :--- |
| **Open Studio Popup** | Left-click on the top bar icon |
| **Launch Full Terminal Studio** | Right-click on the top bar icon |
| **Instant Screensaver Preview** | Middle-click on the top bar icon |

---

## ⌨️ CLI Usage

`omasaver` includes a command-line backend utility for terminal power users:

```bash
# Render ASCII art directly
python3 scripts/omasaver-ctl.py render "OMARCHY" delta_corps_priest_1 center

# Update Omarchy screensaver
python3 scripts/omasaver-ctl.py save-screensaver "OMARCHY" delta_corps_priest_1

# Update Omarchy about logo
python3 scripts/omasaver-ctl.py save-about "OMARCHY" delta_corps_priest_1

# Launch screensaver animation preview
python3 scripts/omasaver-ctl.py preview "OMARCHY" delta_corps_priest_1

# Copy rendered art to clipboard
python3 scripts/omasaver-ctl.py copy "OMARCHY" delta_corps_priest_1
```

---

## 🛠 Dependencies

- **[Omarchy 4](https://omarchy.org/)** (Quickshell / Qt6 QML)
- **[ttfx](https://github.com/ChrisBuilds/terminaltexteffects)** (Terminal text effects engine)
- **[Pyfiglet](https://github.com/patorjk/figlet.js)** (FIGlet ASCII engine)
- **[Textual](https://github.com/Textualize/textual)** (Full TUI Studio)

---

Built with ❤️ for [Omarchy](https://omarchy.org/).
