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
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${SCRIPT_DIR}/Profile"
LOCAL_REPO_DIR="${SCRIPT_DIR}/local-repo"
CORE_REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)/ArcadeLinux-Core/calamares-core"
WORK_DIR="${SCRIPT_DIR}/work"
OUT_DIR="${SCRIPT_DIR}/out"

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
    echo "  --clean      Clean previous build workspaces (work/ and out/)"
    echo "  --sync       Synchronize latest Calamares configs & assets from ArcadeLinux-Core"
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
