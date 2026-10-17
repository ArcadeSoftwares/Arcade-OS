#!/usr/bin/env bash
# ==============================================================================
# Arcade-OS ISO Build & Automation Tool
# ==============================================================================

set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${SCRIPT_DIR}/Profile"
LOCAL_REPO_DIR="${SCRIPT_DIR}/local-repo"
CORE_REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)/ArcadeLinux-Core/calamares-core"
WORK_DIR="${SCRIPT_DIR}/work"
OUT_DIR="${SCRIPT_DIR}/out"

show_banner() {
    local logo_img="${PROFILE_DIR}/airootfs/usr/share/calamares/branding/arcade/arcade-logo.png"
    if [[ ! -f "$logo_img" && -f "/home/abhi9av/Downloads/258029626.jpeg" ]]; then
        logo_img="/home/abhi9av/Downloads/258029626.jpeg"
    fi

    if command -v chafa &>/dev/null && [[ -f "$logo_img" ]]; then
        local img_cols=26
        local img_rows=12
        mapfile -t img < <(chafa "$logo_img" \
            --size "${img_cols}x${img_rows}" \
            --symbols sextant+half+block+quad \
            --colors full \
            --color-space din99d \
            --dither none \
            --work 9 \
            --threshold 0.5 \
            2>/dev/null)

        local banner_lines=(
            ""
            "\033[1;38;2;255;45;85m󰣇 \033[1;38;2;255;45;85m𝗔𝗥𝗖𝗔𝗗𝗘-𝗢𝗦 \033[1;38;2;199;125;255m@ \033[1;38;2;0;229;255m𝗟𝗜𝗡𝗨𝗫\033[0m"
            "\033[38;2;255;45;85m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            " \033[1;38;2;255;45;85m󰣇 System:\033[0m    \033[1;38;2;255;45;85mArcade Linux Live/Install ISO\033[0m"
            " \033[1;38;2;199;125;255m󰌽 Project:\033[0m   \033[1;38;2;199;125;255mArcadeSoftwares/Arcade-OS\033[0m"
            " \033[1;38;2;57;255;20m󱑂 Build:\033[0m     \033[1;38;2;57;255;20mAutomated mkarchiso Engine\033[0m"
            "\033[38;2;0;229;255m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            "   \033[31m \033[32m \033[33m \033[34m \033[35m \033[36m \033[37m\033[0m"
        )

        local max_l=${#img[@]}
        (( ${#banner_lines[@]} > max_l )) && max_l=${#banner_lines[@]}

        echo ""
        for (( i=0; i<max_l; i++ )); do
            local il="${img[$i]:-}"
            local bl="${banner_lines[$i]:-}"
            if [[ -n "$il" ]]; then
                printf '%s\e[0m   %b\n' "$il" "$bl"
            else
                printf '%*s   %b\n' "$img_cols" "" "$bl"
            fi
        done
        echo ""
    else
        echo -e "${CYAN}${BOLD}"
        cat << "EOF"
         ▄▄
        ████          Arcade-OS
       ██████         Arcade Linux Live/Install ISO Build System
      ████████        https://github.com/ArcadeSoftwares/Arcade-OS
     ████  ████
    ████    ████
   ███        ███
  ▀▀            ▀▀
EOF
        echo -e "${NC}"
    fi
}

show_info() {
    local pkg_count=0
    if [[ -f "${PROFILE_DIR}/packages.x86_64" ]]; then
        pkg_count=$(grep -vE '^[[:space:]]*(#|$)' "${PROFILE_DIR}/packages.x86_64" | wc -l)
    fi
    local version="$(date +%Y.%m.%d)"
    local core_status="Available"
    if [[ ! -d "$CORE_REPO_DIR" ]]; then
        core_status="Not Found"
    fi

    local logo_img="${PROFILE_DIR}/airootfs/usr/share/calamares/branding/arcade/arcade-logo.png"
    if [[ ! -f "$logo_img" && -f "/home/abhi9av/Downloads/258029626.jpeg" ]]; then
        logo_img="/home/abhi9av/Downloads/258029626.jpeg"
    fi

    if command -v chafa &>/dev/null && [[ -f "$logo_img" ]]; then
        local img_cols=26
        local img_rows=13
        mapfile -t img < <(chafa "$logo_img" \
            --size "${img_cols}x${img_rows}" \
            --symbols sextant+half+block+quad \
            --colors full \
            --color-space din99d \
            --dither none \
            --work 9 \
            --threshold 0.5 \
            2>/dev/null)

        local info_lines=(
            "\033[1;38;2;255;45;85m󰣇 \033[1;38;2;255;45;85m𝗔𝗥𝗖𝗔𝗗𝗘-𝗢𝗦 \033[1;38;2;199;125;255m@ \033[1;38;2;0;229;255m𝗟𝗜𝗡𝗨𝗫\033[0m"
            "\033[38;2;255;45;85m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            " \033[1;38;2;255;45;85m󰣇 OS:\033[0m        \033[1;38;2;255;45;85mArcade Linux x86_64\033[0m"
            " \033[1;38;2;199;125;255m󰌽 Version:\033[0m   \033[1;38;2;199;125;255m${version} (Rolling)\033[0m"
            " \033[1;38;2;57;255;20m󰧨 Desktop:\033[0m   \033[1;38;2;57;255;20mKDE Plasma 6 (macOS Aesthetic)\033[0m"
            " \033[1;38;2;0;229;255m󰆍 Installer:\033[0m \033[1;38;2;0;229;255mCalamares 3.4.2 (Arcade-Core)\033[0m"
            " \033[1;38;2;255;154;162m󰞷 Author:\033[0m    \033[1;38;2;255;154;162mAbhinav Thakur <thakurabhinav22>\033[0m"
            " \033[1;38;2;0;229;255m󰋊 Profile:\033[0m   \033[0;37m${SCRIPT_DIR}\033[0m"
            "\033[38;2;57;255;20m──────────────────────────────────────\033[0m"
            " \033[1;38;2;255;45;85m󰘚 Packages:\033[0m  \033[1;38;2;255;45;85m${pkg_count} base + desktop + utils\033[0m"
            " \033[1;38;2;57;255;20m󱑂 Core Repo:\033[0m \033[1;38;2;57;255;20m${core_status}\033[0m"
            "\033[38;2;0;229;255m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            "   \033[31m \033[32m \033[33m \033[34m \033[35m \033[36m \033[37m\033[0m"
        )

        local max_l=${#img[@]}
        (( ${#info_lines[@]} > max_l )) && max_l=${#info_lines[@]}

        echo ""
        for (( i=0; i<max_l; i++ )); do
            local il="${img[$i]:-}"
            local infl="${info_lines[$i]:-}"
            if [[ -n "$il" ]]; then
                printf '%s\e[0m   %b\n' "$il" "$infl"
            else
                printf '%*s   %b\n' "$img_cols" "" "$infl"
            fi
        done
        echo ""
    else
        echo ""
        echo -e "         ${CYAN}▄▄${NC}           ${WHITE}${BOLD}Arcade-OS${NC} ${CYAN}(v${version})${NC}"
        echo -e "        ${CYAN}████${NC}          ${WHITE}Abhinav Thakur${NC} ${DIM}<thakurabhinav22>${NC}"
        echo -e "       \033[38;5;45m██████${NC}         ${WHITE}Arch Linux x86_64 • KDE Plasma 6${NC}"
        echo -e "      \033[38;5;39m████████${NC}        ${GRAY}Calamares 3.4.2 • ${pkg_count} Packages${NC}"
        echo -e "     \033[38;5;33m████  ████${NC}       ${DIM}${SCRIPT_DIR}${NC}"
        echo ""
    fi
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

usage() {
    echo -e "${BOLD}Usage:${NC} $0 [options]"
    echo ""
    echo "Options:"
    echo "  --info       Display Arcade-OS branding, system information, and configuration"
    echo "  --clean      Clean previous build workspaces (work/ and out/)"
    echo "  --sync       Synchronize latest Calamares configs & assets from ArcadeLinux-Core"
    echo "  --run        Run the built ISO in QEMU (or use ./run.sh directly)"
    echo "  --help       Show this help message"
    echo ""
    echo "Default action: Validates dependencies, updates pacman repo paths, and builds ISO."
}

check_dependencies() {
    local missing=()
    for cmd in mkarchiso pacman repo-add; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}"
        error "Install them via: sudo pacman -S archiso"
        exit 1
    fi
}

clean_workspace() {
    info "Cleaning workspace directories..."
    if [[ -d "$WORK_DIR" || -d "$OUT_DIR" || -d "${PROFILE_DIR}/work" || -d "${PROFILE_DIR}/out" ]]; then
        sudo rm -rf "$WORK_DIR" "$OUT_DIR" "${PROFILE_DIR}/work" "${PROFILE_DIR}/out"
        success "Cleaned previous build directories."
    else
        info "Workspace is already clean."
    fi
}

sync_core() {
    if [[ -d "$CORE_REPO_DIR" ]]; then
        info "Syncing Calamares assets from ArcadeLinux-Core..."
        
        # Sync Branding
        mkdir -p "${PROFILE_DIR}/airootfs/usr/share/calamares/branding/"
        cp -r "${CORE_REPO_DIR}/branding/arcade" "${PROFILE_DIR}/airootfs/usr/share/calamares/branding/"
        
        # Sync Settings
        mkdir -p "${PROFILE_DIR}/airootfs/etc/calamares/"
        cp "${CORE_REPO_DIR}/settings.conf" "${PROFILE_DIR}/airootfs/etc/calamares/"
        
        # Sync Modules
        mkdir -p "${PROFILE_DIR}/airootfs/etc/calamares/modules/"
        cp -r "${CORE_REPO_DIR}/modules/"* "${PROFILE_DIR}/airootfs/etc/calamares/modules/"
        
        # Sync Package if present
        local pkg
        pkg=$(find "$CORE_REPO_DIR" -maxdepth 1 -name "calamares-[0-9]*.pkg.tar.zst" 2>/dev/null | head -n 1)
        if [[ -n "$pkg" ]]; then
            mkdir -p "$LOCAL_REPO_DIR"
            cp "$pkg" "$LOCAL_REPO_DIR/"
            (
                cd "$LOCAL_REPO_DIR"
                repo-add -R "arcade-local.db.tar.gz" "$(basename "$pkg")" &>/dev/null
            )
            success "Synced Calamares package and updated local-repo."
        fi
        success "Synced Calamares configurations."
    else
        warn "ArcadeLinux-Core not found at ${CORE_REPO_DIR}. Using existing Profile configs."
    fi
}

configure_pacman() {
    info "Configuring repository paths dynamically in Profile/pacman.conf..."
    local conf="${PROFILE_DIR}/pacman.conf"
    
    # Ensure local repo database exists in local-repo if package is present
    if [[ -d "$LOCAL_REPO_DIR" ]]; then
        local local_pkg
        local_pkg=$(find "$LOCAL_REPO_DIR" -maxdepth 1 -name "calamares-*.pkg.tar.zst" 2>/dev/null | head -n 1)
        if [[ -n "$local_pkg" && ! -f "${LOCAL_REPO_DIR}/arcade-local.db.tar.gz" ]]; then
            info "Initializing arcade-local repository database..."
            (cd "$LOCAL_REPO_DIR" && repo-add -R "arcade-local.db.tar.gz" "$(basename "$local_pkg")")
        fi
    fi

    # Ensure repo database exists in ArcadeLinux-Core if present
    if [[ -d "$CORE_REPO_DIR" ]]; then
        local core_pkg
        core_pkg=$(find "$CORE_REPO_DIR" -maxdepth 1 -name "calamares-*.pkg.tar.zst" 2>/dev/null | head -n 1)
        if [[ -n "$core_pkg" && ! -f "${CORE_REPO_DIR}/arcade-local.db.tar.gz" ]]; then
            info "Initializing arcade-local repository database in ArcadeLinux-Core..."
            (cd "$CORE_REPO_DIR" && repo-add -R "arcade-local.db.tar.gz" "$(basename "$core_pkg")")
        fi
    fi

    # Update pacman.conf to use dynamic absolute paths
    local python_script="
import re

conf_path = '${conf}'
with open(conf_path, 'r') as f:
    content = f.read()

pattern = r'\[arcade-local\]\nSigLevel = [^\n]+\n(Server = [^\n]+\n)+'
replacement = '[arcade-local]\nSigLevel = Optional TrustAll\n'
if '${CORE_REPO_DIR}' and '${CORE_REPO_DIR}' != '':
    replacement += 'Server = file://${CORE_REPO_DIR}\n'
replacement += 'Server = file://${LOCAL_REPO_DIR}\n'

new_content = re.sub(pattern, replacement, content)
with open(conf_path, 'w') as f:
    f.write(new_content)
"
    python3 -c "$python_script"
    success "Configured [arcade-local] in ${conf}"
}

build_iso() {
    info "Starting Arcade Linux ISO build..."
    echo -e "${BOLD}Profile directory:${NC} ${PROFILE_DIR}"
    echo -e "${BOLD}Work directory:   ${NC} ${WORK_DIR}"
    echo -e "${BOLD}Output directory: ${NC} ${OUT_DIR}"
    echo ""

    # Ensure stale or incomplete previous build artifacts are cleaned so airootfs.sfs builds properly
    if [[ -d "$WORK_DIR" ]]; then
        if [[ ! -f "${WORK_DIR}/iso/arch/x86_64/airootfs.sfs" || "$DO_CLEAN" == true ]]; then
            warn "Detected incomplete or dirty workspace. Auto-cleaning to ensure rootfs builds cleanly..."
            clean_workspace
        fi
    fi

    mkdir -p "$OUT_DIR"
    sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

    echo ""
    success "ISO build completed successfully!"
    info "Built images:"
    ls -lh "${OUT_DIR}/"*.iso 2>/dev/null || true
    echo ""
    info "To test in QEMU:"
    echo "  qemu-system-x86_64 -m 2G -cdrom out/arcadelinux-*.iso -boot d -vga std -enable-kvm"
}

# ------------------------------------------------------------------------------
# Entrypoint
# ------------------------------------------------------------------------------

DO_CLEAN=false
DO_SYNC=false

# Handle --info directly without showing default build banner
for arg in "$@"; do
    if [[ "$arg" == "--info" ]]; then
        show_info
        exit 0
    fi
done

show_banner

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            DO_CLEAN=true
            shift
            ;;
        --sync)
            DO_SYNC=true
            shift
            ;;
        --run)
            shift
            if [[ -x "${SCRIPT_DIR}/run.sh" ]]; then
                exec "${SCRIPT_DIR}/run.sh" "$@"
            else
                error "run.sh script not found!"
                exit 1
            fi
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

check_dependencies

if [[ "$DO_CLEAN" == true ]]; then
    clean_workspace
fi

if [[ "$DO_SYNC" == true ]]; then
    sync_core
fi

configure_pacman
build_iso
