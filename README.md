# Free Clamshell Mode

Minimal macOS menu bar app that keeps your Mac awake with the lid closed — no AC power required.

## Requirements

- macOS 11.0+
- Swift 5.5+
- Terminal

## Build

```bash
bash build.sh
```

Output: `build/free-clamshell-mode.app`

## Install (optional)

To run at login, copy to Applications:

```bash
cp -r build/free-clamshell-mode.app ~/Applications/
```

Then open the app and enable **Settings > Launch at Login**.

## Usage

1. Build and open the app
2. Laptop icon appears in the menu bar
3. Click the icon to open the menu
4. Click **Free Clamshell** to toggle on/off

The icon turns green when active.

## How It Works

Uses `sudo pmset -a disablesleep 1` to prevent the system from sleeping when the lid is closed, regardless of power source.

| State | Command |
|-------|---------|
| Enable | `sudo pmset -a disablesleep 1` |
| Disable | `sudo pmset -a disablesleep 0` |

## Admin Password — First Time Only

On first activation the app writes a sudoers rule so `pmset` can run without a password prompt on all future uses:

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
| Launch at Login | Off | Auto-start on login |
| Hide from Dock | On | App visible only in menu bar |
| Show Warnings | On | Confirm before enabling |

## Important: Force Quit Behavior

If the app is force-quit while active, `disablesleep` remains set to `1`. To restore normal sleep behavior manually:

```bash
sudo pmset -a disablesleep 0
```

## Troubleshooting

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

**macOS blocks app after rebuild:**
```bash
codesign --remove-signature build/free-clamshell-mode.app
```
