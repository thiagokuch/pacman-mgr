# pacman-mgr 🚀

A lightweight, interactive, and colorful custom CLI wrapper for Arch Linux that seamlessly bridges **pacman** and the **AUR (Arch User Repository)** without depending on third-party AUR helpers. It features native tab-completion support for both **Bash** and **Zsh**, fortified with a transient, zero-trust security auditing engine.

---

## 🌟 Features

* **Dual Mode Engine**: Works both as a single-line CLI command (e.g., `pacman-mgr install vlc`) and a text-based interactive menu.
* **Smart System Updates (`update`)**: Performs a full core system upgrade (`pacman -Syu`). If AUR packages are detected locally, it polls the official AUR RPC API to check for updates and offers a targeted, individual upgrade prompt for each outdated package.
* **Zero-Helper AUR Compilations**: Checks repositories automatically. Official packages are bundled into single `pacman -S` commands, while AUR packages are filtered, cloned via `git`, built via `makepkg`, and handled safely.
* **SUDO-Aware Security Engine**: Safely bypasses the `makepkg as root is not allowed` restriction. Even when running the script with administrative privileges (`sudo`), the AUR compilation process dynamically drops root permissions via `$SUDO_USER` to compile packages safely in a secure user-space environment.
* **Hardened Sandbox Traur Auditing ...**: Automatically integrates `traur` to parse and audit `PKGBUILD` files before compilation. The auditor is executed inside a strict transient **Systemd Sandbox** (`systemd-run`) with no network access (`PrivateNetwork=true`), system write protection (`ProtectSystem=strict`), home isolation (`ProtectHome=true`), and privilege escalation blocks.
* **Strict Zero-Trust Policy enforcement**: Automatically intercepts and **hard-blocks** the execution if a package is flagged as `DANGEROUS`, `MALICIOUS`, or `UNKNOWN`. If the `traur` compliance dependency fails to install or compile from GitHub, the script **immediately aborts the entire execution** to prevent un-audited compilations.
* **Real-time Native Logging**: Outputs operational statuses (`[SUCCESS]`, `[ERROR]`, `[SKIP]`, `[SECURITY_BLOCK]`) directly to the console in real-time, matching standard system package managers.
* **Smart Cache Cleanup**: Leverages `paccache` to prune old configurations safely while keeping recent versions for recovery. Falls back cleanly to `pacman -Sc` if system utilities are missing.
* **Quiet Terminal Completion**: Native interactive prompts inside `remove` and `status` automatically detect terminal capabilities (`[[ $- == *i* ]]`), suppressing annoying `bind: warning: line editing not enabled` warnings during pipeline or non-interactive context executions.
* **Full Tab-Completion**: Intuitively autofills subcommands on the system shell, and dynamically polls your internal database to autocomplete **only currently installed packages** when using removal or status utilities.

---

## 🎨 Interface & Logs Preview

The script uses standard ANSI color coding to emphasize states, actions, and security levels:
* `[INFO]` / `[PACMAN_START]` / `[UPDATE_START]`: Cyan markers for background workflows.
* `[SUCCESS]` / `[AUR_SUCCESS]` / `[UPDATE_SUCCESS]`: Bold green output signals for successful operations.
* `[WARNING]` / `[AUR_CANCEL]`: Yellow prompts when checking unverified repositories or cancelling builds.
* `[ERROR]` / `[AUR_ERROR]` / `[SECURITY_BLOCK]`: Red output tags for invalid states, network errors, or explicit compliance security blocks.

---

## 🛠️ Usage Guide

### Direct Command Line Interface (CLI Mode)

```bash
# Upgrade system repositories and all installed AUR packages
pacman-mgr update

# Install a mix of Official and AUR packages (Triggering Traur automated isolation audit)
pacman-mgr install vlc google-chrome

# Safely remove packages and clean unneeded dependencies (Quiet autocomplete mode)
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
|                                  [Verify/Bootstrap Traur]
|                                  (Fails? -> HARD ABORT)
|                                           |
|                                  [Systemd-Run Sandbox]
|                                  (Audit PKGBUILD via Traur)
|                                           |
|                                  [Policy Enforcement Engine]
|                                  (Dangerous/Malicious? -> BLOCK)
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