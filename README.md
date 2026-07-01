# free-clamshell-mode

<pre>
 _______ .______       _______  _______          ______  __          ___      .___  ___.      _______. __    __   _______  __       __             .___  ___.   ______    _______   _______ 
|   ____||   _  \     |   ____||   ____|        /      ||  |        /   \     |   \/   |     /       ||  |  |  | |   ____||  |     |  |            |   \/   |  /  __  \  |       \ |   ____|
|  |__   |  |_)  |    |  |__   |  |__    ______|  ,----'|  |       /  ^  \    |  \  /  |    |   (----`|  |__|  | |  |__   |  |     |  |      ______|  \  /  | |  |  |  | |  .--.  ||  |__   
|   __|  |      /     |   __|  |   __|  |______|  |     |  |      /  /_\  \   |  |\/|  |     \   \    |   __   | |   __|  |  |     |  |     |______|  |\/|  | |  |  |  | |  |  |  ||   __|  
|  |     |  |\  \----.|  |____ |  |____        |  `----.|  `----./  _____  \  |  |  |  | .----)   |   |  |  |  | |  |____ |  `----.|  `----.       |  |  |  | |  `--'  | |  '--'  ||  |____ 
|__|     | _| `._____||_______||_______|        \______||_______/__/     \__\ |__|  |__| |_______/    |__|  |__| |_______||_______||_______|       |__|  |__|  \______/  |_______/ |_______|
                                                                                                                                                                                            
</pre>

<p align="center">
    <a href="https://www.apple.com/macos/" alt="macOS">
        <img src="https://img.shields.io/badge/macOS_11.0+-000000?style=flat&logo=apple&logoColor=white" /></a>
    <a href="https://www.swift.org/" alt="Swift">
        <img src="https://img.shields.io/badge/Swift_5.5+-F05138?style=flat&logo=swift&logoColor=white" /></a>
    <a href="https://developer.apple.com/xcode/" alt="Xcode Command Line Tools">
        <img src="https://img.shields.io/badge/Xcode_CLT-required-147EFB?style=flat&logo=xcode&logoColor=white" /></a>
    <br>
    <a href="https://github.com/AlejandroPqLz/free-clamshell-mode" alt="GitHub">
        <img src="https://img.shields.io/badge/GitHub-181717?style=flat&logo=github&logoColor=white" /></a>
</p>

Minimal macOS menu bar app that keeps your Mac awake with the lid closed — no AC power required.

## Build

```bash
bash build.sh
```

Output: `build/free-clamshell-mode.app`

## Install (optional)

```bash
cp -r build/free-clamshell-mode.app ~/Applications/
```

Then open the app and enable **Settings > Launch at Login**.

## Usage

1. Build and open the app
2. Clam shell icon appears in the menu bar
3. **Left-click** the icon to toggle on/off
4. **Right-click** (or Ctrl+click) to open the menu

The icon turns into a green scallop fan when active.

## How It Works

Uses `sudo pmset -a disablesleep 1` to prevent the system from sleeping when the lid is closed, regardless of power source.

| State | Command |
|-------|---------|
| Enable | `sudo pmset -a disablesleep 1` |
| Disable | `sudo pmset -a disablesleep 0` |

## Admin Password — First Time Only

On first activation the app writes a sudoers rule so `pmset` can run password-free on all future uses:

```
/etc/sudoers.d/free-clamshell-mode
<username> ALL=(ALL) NOPASSWD: /usr/bin/pmset
```

You will see a macOS admin password dialog once. After that, no password is ever needed again — even after restarts.

To remove this permission manually:

```bash
sudo rm /etc/sudoers.d/free-clamshell-mode
```

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Launch at Login | Off | Auto-start on login via `SMAppService` |
| Hide from Dock | On | App appears only in the menu bar |
| Show Warnings | On | Confirm dialog before enabling |

## Important: Force Quit Behavior

If the app is force-quit while active, `disablesleep` remains set to `1`. Restore normal sleep behavior manually:

```bash
sudo pmset -a disablesleep 0
```

A clean quit (Cmd+Q or Quit from the menu) always resets `disablesleep` to `0` automatically.

## Troubleshooting

**macOS blocks app after rebuild (code signature mismatch):**
```bash
codesign --remove-signature build/free-clamshell-mode.app
```

**"Permission denied":**
```bash
chmod +x build/free-clamshell-mode.app/Contents/MacOS/free-clamshell-mode
```

**"Compilation failed":**
```bash
xcode-select --install
```

**pmset disablesleep stuck at 1:**
```bash
sudo pmset -a disablesleep 0
```
