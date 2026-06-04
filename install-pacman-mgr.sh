#!/bin/bash
# =====================================================================
# PACMAN-MGR INSTALLER WITH ENGLISH SUBCOMMANDS & TAB-COMPLETION
# =====================================================================

echo "Installing pacman-mgr with English subcommands support..."
echo "Creating the main script in /usr/local/bin/pacman-mgr"
echo "Creating BASH completion for subcommands /usr/share/bash-completion/completions/pacman-mgr"
echo "Creating ZSH completion for subcommands /usr/share/zsh/site-functions/_pacman-mgr"

#!/bin/bash
# =====================================================================
# PACMAN-MGR UNIVERSAL AUTOMATIC INSTALLER
# =====================================================================

echo "Installing/Updating the complete version of pacman-mgr..."

# 1. CRIANDO O SCRIPT PRINCIPAL EM /usr/local/bin/pacman-mgr
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
        "SUCCESS"|"PACMAN_SUCCESS"|"AUR_SUCCESS") COLOR=$GREEN ;;
        "ERROR"|"PACMAN_ERROR"|"AUR_ERROR")       COLOR=$RED ;;
        "INFO"|"AUR_START"|"PACMAN_START")        COLOR=$CYAN ;;
        "WARN"|"AUR_CANCEL"|"SKIP")               COLOR=$YELLOW ;;
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

# Function to clean pacman cache
clean_cache() {
    log_message "INFO" "Starting system cache cleanup..."
    if command -v paccache &> /dev/null; then
        echo "Removing uninstalled packages from cache (keeping last 2 versions)..."
        sudo status=0 paccache -r
        echo "Removing all cached versions of uninstalled packages..."
        sudo status=0 paccache -rk0
        log_message "SUCCESS" "Package cache cleanup complete using paccache."
    else
        sudo pacman -Sc --noconfirm
        log_message "SUCCESS" "Package cache cleanup complete using pacman -Sc."
    fi
}

# Function to install AUR packages via makepkg/pacman
install_from_aur() {
    local PKG=$1
    echo -e "\n${RED}${BOLD}⚠️  WARNING: The package '$PKG' comes from the AUR (Arch User Repository).${NC}"
    read -p "Do you want to proceed with the AUR installation? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log_message "AUR_CANCEL" "AUR package '$PKG' installation canceled by the user."
        return 1
    fi

    local BUILD_DIR=$(mktemp -d)
    cd "$BUILD_DIR" || return 1

    if git clone "https://archlinux.org{PKG}.git" &> /dev/null; then
        cd "$PKG" || return 1
        log_message "AUR_START" "Starting compilation of AUR package: $PKG"
        if makepkg -si --noconfirm; then
            log_message "AUR_SUCCESS" "Package '$PKG' successfully installed via AUR."
        else
            log_message "AUR_ERROR" "Failed to compile or install AUR package: $PKG"
        fi
    else
        log_message "AUR_ERROR" "AUR repository not found for: $PKG"
    fi
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

# Function to remove packages
remove_pkg() {
    local PACKAGES=("$@")
    if [ ${#PACKAGES[@]} -eq 0 ]; then
        if [ -n "$BASH_VERSION" ]; then
            bind 'set disable-completion off'
            bind 'TAB: menu-complete'
            complete -W "$(pacman -Qq)" read
        fi
        read -e -p "Enter package name(s) to remove (separated by spaces): " -a PACKAGES
        if [ -n "$BASH_VERSION" ]; then complete -r read; fi
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

# Function to analyze packages
check_pkg() {
    local PACKAGES=("$@")
    if [ ${#PACKAGES[@]} -eq 0 ]; then
        if [ -n "$BASH_VERSION" ]; then
            bind 'set disable-completion off'
            bind 'TAB: menu-complete'
            complete -W "$(pacman -Qq)" read
        fi
        read -e -p "Enter package name(s) to analyze (separated by spaces): " -a PACKAGES
        if [ -n "$BASH_VERSION" ]; then complete -r read; fi
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
                if curl -s "https://archlinux.org[]=${PKG}" | grep -q '"resultcount":1'; then
                    echo -e "Note: Available to install via ${YELLOW}AUR${NC}."
                else
                    echo -e "${RED}Error: Package not found in Official Repositories or AUR.${NC}"
                fi
            fi
        fi
    done
}

# Check if arguments were passed directly on execution (CLI mode)
if [ $# -gt 0 ]; then
    COMMAND=$1
    shift # Remove the first argument to leave only package names
    case $COMMAND in
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

# Main Menu Loop (Interactive mode)
while true; do
    echo -e "\n${MAGENTA}=============================="
    echo -e " ${BOLD}Pacman + AUR Package Manager${NC} "
    echo -e "${MAGENTA}=============================="
    echo -e "${CYAN}install${NC} - Install package(s) (Repo/AUR)"
    echo -e "${CYAN}remove${NC}  - Remove package(s)"
    echo -e "${CYAN}status${NC}  - Analyze package(s)"
    echo -e "${CYAN}clean${NC}   - Clean Package Cache"
    echo -e "${CYAN}help${NC}    - View CLI Manual"
    echo -e "${CYAN}exit${NC}    - Exit"
    read -p "Choose a command: " CHOICE

    case $CHOICE in
        install) install_pkg ;;
        remove)  remove_pkg ;;
        status)  check_pkg ;;
        clean)   clean_cache ;;
        help)    show_help ;;
        exit)    echo "Exiting."; exit 0 ;;
        *)       echo -e "${RED}Invalid command. Please try: install, remove, status, clean, help, exit.${NC}" ;;
    esac
done
EOF

# 2. CONCEDENDO PERMISSÕES DE EXECUÇÃO
chmod +x /usr/local/bin/pacman-mgr

# 3. CRIANDO AUTOCOMPLETAR PARA O BASH
mkdir -p /usr/share/bash-completion/completions

cat << 'EOF' > /usr/share/bash-completion/completions/pacman-mgr
_pacman_mgr_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="install remove status clean help -h --help exit"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi

    case "${prev}" in
        remove|status)
            COMPREPLY=( $(compgen -W "$(pacman -Qq)" -- "${cur}") )
            return 0
            ;;
    esac
}
complete -F _pacman_mgr_completion pacman-mgr
EOF

# 4. CRIANDO AUTOCOMPLETAR PARA O ZSH
mkdir -p /usr/share/zsh/site-functions

cat << 'EOF' > /usr/share/zsh/site-functions/_pacman-mgr
#compdef pacman-mgr

_pacman-mgr() {
    local context state line
    typeset -A opt_args

    _arguments \
        '1:Subcommand:(install remove status clean help -h --help exit)' \
        '*:Package:->_packages'

    case $words in
        remove|status)
            _values 'installed packages' $(pacman -Qq)
            ;;
    esac
}
EOF

echo "--------------------------------------------------"
echo " Installation/Update Completed Successfully!"
echo " Open a new terminal window to use: pacman-mgr"
echo "--------------------------------------------------"

