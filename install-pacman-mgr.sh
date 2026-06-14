#!/bin/bash
# =====================================================================
# PACMAN-MGR UNIVERSAL AUTOMATIC INSTALLER (HARDENED SANDBOX EDITION)
# =====================================================================

# Check if the script is running as Root/Sudo to allow installation in system directories
if [ "$EUID" -ne 0 ]; then
    echo "Please execute this installer as root or using sudo!"
    exit 1
fi

echo "Installing/Updating the secure version of pacman-mgr with Hardened Sandbox Traur auditing..."

# 1. CREATING THE MAIN CORE SCRIPT IN /usr/local/bin/pacman-mgr
cat << 'EOF' > /usr/local/bin/pacman-mgr
#!/bin/bash

# ANSI Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color (Reset)

# Function to print colored logs directly to the console
log_message() {
    local TYPE=$1
    local MESSAGE=$2
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    local COLOR=$NC

    case $TYPE in
        "SUCCESS"|"PACMAN_SUCCESS"|"AUR_SUCCESS"|"UPDATE_SUCCESS") COLOR=$GREEN ;;
        "ERROR"|"PACMAN_ERROR"|"AUR_ERROR"|"UPDATE_ERROR"|"SECURITY_BLOCK") COLOR=$RED ;;
        "INFO"|"AUR_START"|"PACMAN_START"|"UPDATE_START")         COLOR=$CYAN ;;
        "WARN"|"AUR_CANCEL"|"SKIP")                               COLOR=$YELLOW ;;
    esac

    echo -e "${BOLD}[$TIMESTAMP]${NC} ${COLOR}${BOLD}[$TYPE]${NC} ${COLOR}$MESSAGE${NC}" >&2
}

# Function to display the help documentation
show_help() {
    echo -e "${MAGENTA}${BOLD}==================================================${NC}"
    echo -e "  ${BOLD}Pacman + AUR Manager (pacman-mgr) - Help Manual${NC}"
    echo -e "${MAGENTA}${BOLD}==================================================${NC}"
    echo -e "${BOLD}USAGE:${NC}"
    echo -e "  pacman-mgr [command] [options/packages]\n"
    echo -e "${BOLD}COMMANDS:${NC}"
    echo -e "  ${CYAN}update${NC}           Updates the system database and upgrades all packages (Repo + AUR)."
    echo -e "  ${CYAN}install${NC} [pkgs]   Installs packages from Official Repositories or AUR."
    echo -e "                  Multiple packages can be separated by spaces."
    echo -e "  ${CYAN}remove${NC}  [pkgs]   Safely removes packages and their orphaned dependencies."
    echo -e "  ${CYAN}status${NC}  [pkgs]   Analyzes package metadata (version, install date, size)"
    echo -e "                  and queries the official web API if available on AUR."
    echo -e "  ${CYAN}clean${NC}            Cleans the system cache to free up disk space."
    echo -e "  ${CYAN}help, -h, --help${NC} Displays this help manual.\n"
    echo -e "${BOLD}INTERACTIVE MODE:${NC}"
    echo -e "  Running ${GREEN}pacman-mgr${NC} without arguments opens a text-based menu."
    echo -e "${MAGENTA}${BOLD}--------------------------------------------------${NC}"
}

# Function to update the official database
update_db() {
    log_message "INFO" "Updating pacman package database..."
    if sudo pacman -Sy; then
        log_message "SUCCESS" "Pacman package database updated."
    else
        log_message "ERROR" "Failed to update package database."
    fi
}

# Function to update the system (Official Repos + AUR)
update_system() {
    log_message "UPDATE_START" "Starting full core system upgrade (pacman -Syu)..."
    if sudo pacman -Syu; then
        log_message "UPDATE_SUCCESS" "Official repositories system upgrade completed successfully."
    else
        log_message "UPDATE_ERROR" "Core system upgrade failed."
        return 1
    fi

    local AUR_PKGS=$(pacman -Qm | awk '{print $1}')
    if [ -n "$AUR_PKGS" ]; then
        echo -e "\n${YELLOW}${BOLD}Checking for AUR package updates...${NC}"
        for PKG in $AUR_PKGS; do
            local REMOTE_VER=$(curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=${PKG}" | grep -oP '"Version":"\K[^"]+')
            local LOCAL_VER=$(pacman -Qi "$PKG" | grep -i "Version" | awk -F': ' '{print $2}')

            if [ -n "$REMOTE_VER" ] && [ "$REMOTE_VER" != "$LOCAL_VER" ]; then
                echo -e "${CYAN}Update available for AUR package [${PKG}]: ${RED}${LOCAL_VER}${NC} -> ${GREEN}${REMOTE_VER}${NC}"
                read -p "Do you want to upgrade ${PKG}? [y/N]: " CONFIRM_UP
                if [[ "$CONFIRM_UP" =~ ^[Yy]$ ]]; then
                    install_from_aur "$PKG"
                else
                    log_message "SKIP" "Skipping update for ${PKG}."
                fi
            fi
        done
        log_message "SUCCESS" "AUR packages check complete."
    fi
}

# Function to clean pacman cache
clean_cache() {
    log_message "INFO" "Starting system cache cleanup..."
    if command -v paccache &> /dev/null; then
        echo "Removing uninstalled packages from cache (keeping last 2 versions)..."
        sudo paccache -r
        echo "Removing all cached versions of uninstalled packages..."
        sudo paccache -rk0
        log_message "SUCCESS" "Package cache cleanup complete using paccache."
    else
        sudo pacman -Sc --noconfirm
        log_message "SUCCESS" "Package cache cleanup complete using pacman -Sc."
    fi
}

# Function to securely build and install Traur directly from official GitHub
bootstrap_traur() {
    local REAL_USER=${SUDO_USER:-$USER}
    log_message "INFO" "Bootstrapping 'traur' directly from official GitHub repository..."

    if ! command -v cargo &> /dev/null; then
        log_message "INFO" "Rust environment (cargo) missing. Installing default toolchain..."
        sudo pacman -S rust --noconfirm
    fi

    local T_BUILD_DIR=$(mktemp -d)
    chown -R "$REAL_USER":"$REAL_USER" "$T_BUILD_DIR"
    cd "$T_BUILD_DIR" || return 1

    if sudo -u "$REAL_USER" git clone "https://github.com/Sohimaster/traur" &> /dev/null; then
        cd traur || return 1
        log_message "INFO" "Compiling traur binary via cargo..."
        if sudo -u "$REAL_USER" cargo build --release &> /dev/null; then
            log_message "INFO" "Deploying traur system-wide..."
            cp target/release/traur /usr/local/bin/traur
            chmod +x /usr/local/bin/traur
            log_message "SUCCESS" "'traur' security auditor successfully compiled and deployed."
            cd ~ || return 1
            rm -rf "$T_BUILD_DIR"
            return 0
        fi
    fi

    log_message "ERROR" "Failed to compile 'traur' from GitHub."
    cd ~ || return 1
    rm -rf "$T_BUILD_DIR"
    return 1
}

# Function to install AUR packages via makepkg/pacman with Hardened Sandbox Traur Auditing
install_from_aur() {
    local PKG=$1
    local REAL_USER=${SUDO_USER:-$USER}

    # 1. VERIFY AND BOOTSTRAP TRAUR SECURELY FROM GITHUB
    if ! command -v traur &> /dev/null; then
        echo -e "\n${YELLOW}${BOLD}🔍 DEPENDENCY INFO: 'traur' (AUR Auditor) is not installed.${NC}"
        read -p "Do you want to securely compile 'traur' from GitHub to audit AUR packages? [Y/n]: " INSTALL_TRAUR
        INSTALL_TRAUR=${INSTALL_TRAUR:-Y}

        if [[ "$INSTALL_TRAUR" =~ ^[Yy]$ ]]; then
            if ! bootstrap_traur; then
                log_message "ERROR" "CRITICAL COMPLIANCE FAILURE: Failed to deploy secure dependency 'traur'. Aborting '$PKG' installation."
                return 1
            fi
        else
            log_message "WARN" "Proceeding without 'traur' is highly discouraged due to recent AUR exploits."
            read -p "Are you absolutely sure you want to skip auditing for '$PKG'? [y/N]: " SKIP_CONFIRM
            if [[ ! "$SKIP_CONFIRM" =~ ^[Yy]$ ]]; then
                log_message "AUR_CANCEL" "Installation canceled by user."
                return 1
            fi
        fi
    fi

    # 2. TARGET AUR PACKAGE INSTALLATION PROCESS
    echo -e "\n${RED}${BOLD}⚠️  WARNING: The package '$PKG' comes from the AUR (Arch User Repository).${NC}"
    read -p "Do you want to proceed with the AUR installation? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log_message "AUR_CANCEL" "AUR package '$PKG' installation canceled by the user."
        return 1
    fi

    local BUILD_DIR=$(mktemp -d)
    chown -R "$REAL_USER":"$REAL_USER" "$BUILD_DIR"
    cd "$BUILD_DIR" || return 1

    log_message "INFO" "Cloning AUR repository for $PKG..."
    if sudo -u "$REAL_USER" git clone "https://aur.archlinux.org/${PKG}.git" &> /dev/null; then
        cd "$PKG" || return 1
        chown -R "$REAL_USER":"$REAL_USER" "$BUILD_DIR/$PKG"

        # 3. CODE AUDITING VIA HARDENED SYSTEMD-RUN SANDBOX
        if command -v traur &> /dev/null; then
            echo -e "\n${MAGENTA}${BOLD}┌──────────────────────────────────────────────────────────┐${NC}"
            echo -e "│         TRAUR SECURITY AUDIT REPORT (HARDENED SANDBOX)   │"
            echo -e "└──────────────────────────────────────────────────────────┘${NC}"

            local AUDIT_LOG=$(mktemp)
            chown "$REAL_USER":"$REAL_USER" "$AUDIT_LOG"

            # Executing traur under a transient systemd sandbox with custom strict policies
            systemd-run --user --wait --pipe \
                --property=PrivateNetwork=true \
                --property=ProtectSystem=strict \
                --property=ProtectHome=true \
                --property=NoNewPrivileges=true \
                --property=CapabilityBoundingSet="" \
                --property=RestrictNamespaces=true \
                --property=BindPaths="$BUILD_DIR/$PKG" \
                /usr/local/bin/traur PKGBUILD 2>/dev/null | tee "$AUDIT_LOG"

            echo -e "${MAGENTA}${BOLD}┌──────────────────────────────────────────────────────────┐${NC}"
            echo -e "│                       END OF REPORT                      │"
            echo -e "└──────────────────────────────────────────────────────────┘${NC}"

            local CLASSIFICATION="UNKNOWN"
            if grep -iq "MALICIOUS" "$AUDIT_LOG"; then CLASSIFICATION="MALICIOUS"
            elif grep -iq "DANGEROUS" "$AUDIT_LOG"; then CLASSIFICATION="DANGEROUS"
            elif grep -iq "SUSPICIOUS" "$AUDIT_LOG"; then CLASSIFICATION="SUSPICIOUS"
            elif grep -iq "REVIEW" "$AUDIT_LOG"; then CLASSIFICATION="REVIEW"
            elif grep -iq "OK" "$AUDIT_LOG"; then CLASSIFICATION="OK"
            elif grep -iq "SAFE" "$AUDIT_LOG"; then CLASSIFICATION="SAFE"
            fi

            rm -f "$AUDIT_LOG"

            # Render Dynamic Assessment Banner
            echo -e "\n${BOLD}📊 AUDIT ASSESSMENT RESULTS:${NC}"
            case "$CLASSIFICATION" in
                "SAFE")
                    echo -e "${GREEN}${BOLD}==================================================${NC}"
                    echo -e "${GREEN}${BOLD}🛡️  TRUST LEVEL: SAFE (90-100)                      ${NC}"
                    echo -e "${GREEN}No unusual behavior or dangerous commands found.  ${NC}"
                    echo -e "${GREEN}${BOLD}==================================================${NC}"
                    ;;
                "OK")
                    echo -e "${GREEN}${BOLD}==================================================${NC}"
                    echo -e "${GREEN}${BOLD}✅ TRUST LEVEL: OK (75-89)                        ${NC}"
                    echo -e "${GREEN}Normal package complexity. Review is optional.    ${NC}"
                    echo -e "${GREEN}${BOLD}==================================================${NC}"
                    ;;
                "REVIEW")
                    echo -e "${YELLOW}${BOLD}==================================================${NC}"
                    echo -e "${YELLOW}${BOLD}⚠️  TRUST LEVEL: REVIEW (60-74)                    ${NC}"
                    echo -e "${YELLOW}Some flags detected. Inspection is recommended.  ${NC}"
                    echo -e "${YELLOW}${BOLD}==================================================${NC}"
                    ;;
                "SUSPICIOUS")
                    echo -e "${YELLOW}${BOLD}==================================================${NC}"
                    echo -e "${YELLOW}${BOLD}⚡ TRUST LEVEL: SUSPICIOUS (40-59)                ${NC}"
                    echo -e "${YELLOW}Multiple suspicious indicators found. Be careful! ${NC}"
                    echo -e "${YELLOW}${BOLD}==================================================${NC}"
                    ;;
                "DANGEROUS")
                    echo -e "${RED}${BOLD}==================================================${NC}"
                    echo -e "${RED}${BOLD}🚨 TRUST LEVEL: DANGEROUS (20-39)                 ${NC}"
                    echo -e "${RED}High risk variables or dangerous actions found.    ${NC}"
                    echo -e "${RED}${BOLD}==================================================${NC}"
                    ;;
                "MALICIOUS")
                    echo -e "${RED}${BOLD}==================================================${NC}"
                    echo -e "${RED}${BOLD}❌ TRUST LEVEL: MALICIOUS (0-19)                  ${NC}"
                    echo -e "${RED}CRITICAL SECURITY PATTERNS DETECTED!              ${NC}"
                    echo -e "${RED}${BOLD}==================================================${NC}"
                    ;;
                *)
                    echo -e "${RED}${BOLD}==================================================${NC}"
                    echo -e "${RED}${BOLD}❓ TRUST LEVEL: UNKNOWN / INVALID SCORE           ${NC}"
                    echo -e "${RED}Security risk: traur output signature is missing.  ${NC}"
                    echo -e "${RED}${BOLD}==================================================${NC}"
                    ;;
            esac

            # AUTOMATIC POLICY ENFORCEMENT HALT
            if [ "$CLASSIFICATION" = "DANGEROUS" ] || [ "$CLASSIFICATION" = "MALICIOUS" ] || [ "$CLASSIFICATION" = "UNKNOWN" ]; then
                echo -e "\n${RED}${BOLD}╔═════════════════════════════════════════════════════════════════════════╗${NC}"
                echo -e "║ 🛑 SECURITY ALERT: INSTALLATION HARD-BLOCKED                            ║"
                echo -e "╚═════════════════════════════════════════════════════════════════════════╝${NC}"
                if [ "$CLASSIFICATION" = "UNKNOWN" ]; then
                    echo -e "${YELLOW}Reason: The package evaluation returned an [UNKNOWN] status.${NC}"
                    echo -e "${YELLOW}This means 'traur' could not verify the PKGBUILD syntax safely, or the score is absent.${NC}"
                else
                    echo -e "${YELLOW}Reason: The package trust score is too low (${CLASSIFICATION}).${NC}"
                fi
                echo -e "${CYAN}Action: In accordance with our zero-trust policy, compilation has been stopped.${NC}"
                echo -e "${CYAN}        All temporary build assets and git source trees have been erased.${NC}\n"

                log_message "SECURITY_BLOCK" "Transaction terminated for '$PKG'. Execution halted."

                cd ~ || return 1
                rm -rf "$BUILD_DIR"
                return 1
            fi

            read -p "Did you review the audit? Do you trust this package to proceed? [y/N]: " AUDIT_CONFIRM
            if [[ ! "$AUDIT_CONFIRM" =~ ^[Yy]$ ]]; then
                log_message "AUR_CANCEL" "Security alert: Package '$PKG' rejected by the user after audit."
                cd ~ || return 1
                rm -rf "$BUILD_DIR"
                return 1
            fi
        fi

        # 4. COMPILATION AND TARGET DEPLOYMENT
        log_message "AUR_START" "Starting compilation of AUR package: $PKG"
        if sudo -u "$REAL_USER" makepkg -si --noconfirm; then
            log_message "AUR_SUCCESS" "Package '$PKG' successfully installed via AUR."
        else
            log_message "AUR_ERROR" "Failed to compile or install AUR package: $PKG"
        fi
    else
        log_message "AUR_ERROR" "AUR repository not found for: $PKG"
    fi

    # 5. ENVIRONMENT PURGE AND CLEANUP
    cd ~ || return 1
    rm -rf "$BUILD_DIR"
}

# Function to install packages
install_pkg() {
    local PACKAGES=("$@")
    if [ ${#PACKAGES[@]} -eq 0 ]; then
        read -e -p "Enter package name(s) separated by spaces: " -a PACKAGES
    fi
    if [ ${#PACKAGES[@]} -eq 0 ]; then return; fi

    local OFFICIAL_TO_INSTALL=()
    local AUR_TO_INSTALL=()
    local DB_UPDATED=false

    for PKG in "${PACKAGES[@]}"; do
        if pacman -Qi "$PKG" &> /dev/null; then
            log_message "SKIP" "'$PKG' is already installed. Skipping."
        else
            if pacman -Si "$PKG" &> /dev/null; then
                OFFICIAL_TO_INSTALL+=("$PKG")
            else
                AUR_TO_INSTALL+=("$PKG")
            fi
        fi
    done

    if [ ${#OFFICIAL_TO_INSTALL[@]} -gt 0 ]; then
        update_db
        DB_UPDATED=true
        log_message "PACMAN_START" "Installing official packages: ${OFFICIAL_TO_INSTALL[*]}"
        if sudo pacman -S "${OFFICIAL_TO_INSTALL[@]}"; then
            log_message "PACMAN_SUCCESS" "Official packages installed: ${OFFICIAL_TO_INSTALL[*]}"
        else
            log_message "PACMAN_ERROR" "Failed to install official packages: ${OFFICIAL_TO_INSTALL[*]}"
        fi
    fi

    for AUR_PKG in "${AUR_TO_INSTALL[@]}"; do
        if [ "$DB_UPDATED" = false ]; then
            update_db
            DB_UPDATED=true
        fi
        install_from_aur "$AUR_PKG"
    done
}

# Function to remove packages (Safely structured to ignore bind warnings)
remove_pkg() {
    local PACKAGES=("$@")
    if [ ${#PACKAGES[@]} -eq 0 ]; then
        if [ -n "$BASH_VERSION" ] && [[ $- == *i* ]]; then
            bind 'set disable-completion off' 2>/dev/null
            bind 'TAB: menu-complete' 2>/dev/null
            complete -W "$(pacman -Qq)" read 2>/dev/null
        fi
        read -e -p "Enter package name(s) to remove (separated by spaces): " -a PACKAGES
        if [ -n "$BASH_VERSION" ] && [[ $- == *i* ]]; then complete -r read 2>/dev/null; fi
    fi
    if [ ${#PACKAGES[@]} -eq 0 ]; then return; fi

    local TO_REMOVE=()
    for PKG in "${PACKAGES[@]}"; do
        if ! pacman -Qi "$PKG" &> /dev/null; then
            log_message "SKIP" "'$PKG' is not installed. Skipping."
        else
            TO_REMOVE+=("$PKG")
        fi
    done

    if [ ${#TO_REMOVE[@]} -gt 0 ]; then
        log_message "REMOVE_START" "Removing packages and orphaned dependencies: ${TO_REMOVE[*]}"
        if sudo pacman -Rns "${TO_REMOVE[@]}"; then
            log_message "REMOVE_SUCCESS" "Packages successfully removed: ${TO_REMOVE[*]}"
        else
            log_message "REMOVE_ERROR" "Failed to remove packages: ${TO_REMOVE[*]}"
        fi
    fi
}

# Function to analyze packages (Safely structured to ignore bind warnings)
check_pkg() {
    local PACKAGES=("$@")
    if [ ${#PACKAGES[@]} -eq 0 ]; then
        if [ -n "$BASH_VERSION" ] && [[ $- == *i* ]]; then
            bind 'set disable-completion off' 2>/dev/null
            bind 'TAB: menu-complete' 2>/dev/null
            complete -W "$(pacman -Qq)" read 2>/dev/null
        fi
        read -e -p "Enter package name(s) to analyze (separated by spaces): " -a PACKAGES
        if [ -n "$BASH_VERSION" ] && [[ $- == *i* ]]; then complete -r read 2>/dev/null; fi
    fi
    if [ ${#PACKAGES[@]} -eq 0 ]; then return; fi

    for PKG in "${PACKAGES[@]}"; do
        echo -e "\n${BOLD}--- Status for '$PKG' ---${NC}"
        if pacman -Qi "$PKG" &> /dev/null; then
            echo -e "Status: ${GREEN}${BOLD}INSTALLED${NC}"
            pacman -Qi "$PKG" | grep -E "(Version|Install Date|Installed Size)"
        else
            echo -e "Status: ${RED}${BOLD}NOT installed${NC}"
            if pacman -Si "$PKG" &> /dev/null; then
                echo -e "Note: Available to install from ${CYAN}Official Repositories${NC}."
            else
                echo "Searching the AUR..."
                if curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=${PKG}" | grep -q '"resultcount":1'; then
                    echo -e "Note: Available to install via ${YELLOW}AUR${NC}."
                else
                    echo -e "${RED}Error: Package not found in Official Repositories or AUR.${NC}"
                fi
            fi
        fi
    done
}

# Core Parser Logic for Direct CLI Invocation
if [ $# -gt 0 ]; then
    COMMAND=$1
    shift
    case $COMMAND in
        update)           update_system ;;
        install)          install_pkg "$@" ;;
        remove)           remove_pkg "$@" ;;
        status)           check_pkg "$@" ;;
        clean)            clean_cache ;;
        help|-h|--help)   show_help ;;
        *)
            echo -e "${RED}Unknown command: '$COMMAND'${NC}"
            show_help
            exit 1
            ;;
    esac
    exit 0
fi

# Text-Based Interactive Dashboard (Main Loop)
while true; do
    echo -e "\n${MAGENTA}=============================="
    echo -e " ${BOLD}Pacman + AUR Package Manager${NC} "
    echo -e "${MAGENTA}=============================="
    echo -e "${CYAN}update${NC}  - Upgrade system & AUR local packages"
    echo -e "${CYAN}install${NC} - Install package(s) (Repo/AUR)"
    echo -e "${CYAN}remove${NC}  - Remove package(s)"
    echo -e "${CYAN}status${NC}  - Analyze package(s)"
    echo -e "${CYAN}clean${NC}   - Clean Package Cache"
    echo -e "${CYAN}help${NC}    - View CLI Manual"
    echo -e "${CYAN}exit${NC}    - Exit"
    read -p "Choose a command: " CHOICE

    case $CHOICE in
        update)  update_system ;;
        install) install_pkg ;;
        remove)  remove_pkg ;;
        status)  check_pkg ;;
        clean)   clean_cache ;;
        help)    show_help ;;
        exit)    echo "Exiting."; exit 0 ;;
        *)       echo -e "${RED}Invalid command. Please try: update, install, remove, status, clean, help, exit.${NC}" ;;
    esac
done
EOF

# 2. GRANTING DIRECTORY EXECUTION PRIVILEGES
chmod +x /usr/local/bin/pacman-mgr

# 3. GENERATING SYSTEM-WIDE BASH TAB-COMPLETION RULES
mkdir -p /usr/share/bash-completion/completions

cat << 'EOF' > /usr/share/bash-completion/completions/pacman-mgr
_pacman_mgr_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="update install remove status clean help -h --help exit"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi

    case "${prev}" in
        remove|status)
            COMPREPLY=( $(compgen -W "$(pacman -Qq)" -- "${cur}") )
            return 0
            ;;
        install)
            COMPREPLY=( $(compgen -W "$(pacman -Ssq 2>/dev/null)" -- "${cur}") )
            return 0
            ;;
    esac
}
complete -F _pacman_mgr_completion pacman-mgr
EOF

# 4. GENERATING NATIVE ZSH TAB-COMPLETION RULES
mkdir -p /usr/share/zsh/site-functions

cat << 'EOF' > /usr/share/zsh/site-functions/_pacman-mgr
#compdef pacman-mgr

_pacman-mgr() {
    local context state line
    typeset -A opt_args

    _arguments \
        '1:Subcommand:(update install remove status clean help -h --help exit)' \
        '*:Package:->_packages'

    case $state in
        *)
            case $words[2] in
                remove|status)
                    _values 'installed packages' $(pacman -Qq)
                    ;;
                install)
                    _message 'Enter official or AUR package name'
                    ;;
            esac
            ;;
    esac
}
_pacman-mgr "$@"
EOF

echo "--------------------------------------------------"
echo " Hardened Installation Completed Successfully!"
echo " Open a new terminal window to use: pacman-mgr"
echo "--------------------------------------------------"