# pacman-mgr 🚀

A lightweight, interactive, and colorful custom CLI wrapper for Arch Linux that seamlessly bridges **pacman** and the **AUR (Arch User Repository)** without depending on third-party AUR helpers. It features native tab-completion support for both **Bash** and **Zsh**.
---

## 🌟 Features

*   **Dual Mode Engine**: Works both as a single-line CLI command (e.g., `pacman-mgr install vlc`) and a text-based interactive menu.
*   **Smart System Updates (`update`)**: Performs a full core system upgrade (`pacman -Syu`). If AUR packages are detected locally, it polls the official AUR RPC API to check for updates and offers a targeted, individual upgrade prompt for each outdated package.
*   **Zero-Helper AUR Compilations**: Checks repositories automatically. Official packages are bundled into single `pacman -S` commands, while AUR packages are filtered, cloned via `git`, built via `makepkg`, and handled safely.
*   **SUDO-Aware Security Engine**: Safely bypasses the `makepkg as root is not allowed` restriction. Even when running the script with administrative privileges (`sudo`), the AUR compilation process dynamically drops root permissions via `$SUDO_USER` to compile packages safely in a secure user-space environment.
*   **Security Confirmations**: Explicitly prompts the user with warnings before building or modifying code coming from the AUR.
*   **Real-time Native Logging**: Outputs operational statuses (`[SUCCESS]`, `[ERROR]`, `[SKIP]`, `[UPDATE_START]`) directly to the console in real-time, matching standard system package managers.
*   **Smart Cache Cleanup**: Leverages `paccache` to prune old configurations safely while keeping recent versions for recovery. Falls back cleanly to `pacman -Sc` if system utilities are missing.
*   **Full Tab-Completion**: Intuitively autofills subcommands (including the new `update`) on the system shell, and dynamically polls your internal database to autocomplete **only currently installed packages** when using removal or status utilities.

---

## 🎨 Interface & Logs Preview

The script uses standard ANSI color coding to emphasize states and actions:
*   `[INFO]` / `[PACMAN_START]` / `[UPDATE_START]`: Cyan markers for background workflows.
*   `[SUCCESS]` / `[AUR_SUCCESS]` / `[UPDATE_SUCCESS]`: Bold green output signals for successful operations.
*   `[WARNING]` / `[AUR_CANCEL]`: Yellow prompts when checking unverified repositories or cancelling builds.
*   `[ERROR]` / `[AUR_ERROR]` / `[UPDATE_ERROR]`: Red output tags for invalid states, network errors, or cancelled builds.

---

## 🛠️ Usage Guide

### Direct Command Line Interface (CLI Mode)

```bash
# Upgrade system repositories and all installed AUR packages
pacman-mgr update

# Install a mix of Official and AUR packages
pacman-mgr install vlc google-chrome

# Safely remove packages and clean unneeded dependencies
pacman-mgr remove firefox

# View detailed installation metadata and size metrics
pacman-mgr status htop

# Erase stale packages from cache
pacman-mgr clean

# View the integrated manual
pacman-mgr --help
```

### Interactive Menu Mode

Simply run the script with no arguments to load the interactive English control system:
```bash
pacman-mgr
```

---

## 📦 Script Architecture Diagram

```text
                    [User Input: pacman-mgr update / install]
                                        |
                  ┌─────────────────────┴─────────────────────┐
                  ▼                                           ▼
          [Official Repo]                                   [AUR]
      (Database sync / Core)                         (RPC API Lookup)
                  |                                           |
       Runs: sudo pacman -S/Syu                     Prompts Warning & Confirm
                  |                                           |
                  |                                 Drops root to $SUDO_USER
                  |                                 Clones git repository
                  |                                 Compiles via makepkg
                  ▼                                           ▼
         [ ────────────── System Installation via Pacman Backend ────────────── ]
```

---

## 🔧 Installation & Global Setup

To set up the script alongside the global autocompletion definitions manually, follow these configuration phases:

### 1. Main Bin Deployment
Save the core codebase to `/usr/local/bin/pacman-mgr`, discard any trailing file extensions, and flag it as an executable:
```bash
sudo chmod +x /usr/local/bin/pacman-mgr
```

### 2. Tab-Completion Registration

#### For Bash Shell users:
Deploy the structural shell hooks to the standard system completions path:
```bash
sudo touch /usr/share/bash-completion/completions/pacman-mgr
# Apply the Bash block here
```

#### For Zsh Shell users:
Inject the definitions parameter directly inside your system site-functions:
```bash
sudo touch /usr/share/zsh/site-functions/_pacman-mgr
# Apply the Zsh block here
```

### 3. Finalize
Restart your active shell environment or spawn a new terminal window to load the pathing adjustments:
```bash
exec \$SHELL
```
