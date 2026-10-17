#!/usr/bin/env bash
# ==============================================================================
# Arcade-OS Universal Build & Runner Engine (build.sh)
# Builds, tests, syncs, and boots Arcade Linux ISOs
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${SCRIPT_DIR}/Profile"
WORK_DIR="${SCRIPT_DIR}/work"
OUT_DIR="${SCRIPT_DIR}/out"
LOCAL_REPO_DIR="${SCRIPT_DIR}/local-repo"
LOGO_IMG="${SCRIPT_DIR}/branding/arcade-logo.png"

# Auto-detect ArcadeLinux-Core location
CORE_REPO_DIR=""
if [[ -d "/home/abhi9av/Desktop/ArcadeLinux-Core" ]]; then
    CORE_REPO_DIR="/home/abhi9av/Desktop/ArcadeLinux-Core"
elif [[ -d "${SCRIPT_DIR}/../ArcadeLinux-Core" ]]; then
    CORE_REPO_DIR="$(cd "${SCRIPT_DIR}/../ArcadeLinux-Core" && pwd)"
fi

# ANSI Colors
CYAN='\033[38;5;51m'
BLUE='\033[38;5;39m'
GREEN='\033[38;5;48m'
YELLOW='\033[38;5;220m'
RED='\033[38;5;196m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;245m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# Step counter
CURRENT_STEP=0
TOTAL_STEPS=5

step_header() {
    local step_title="$1"
    (( CURRENT_STEP++ )) || true
    echo ""
    echo -e "  ${CYAN}╭──────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "  ${CYAN}│${NC}  ${BOLD}${BLUE}󰣇 [STEP ${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${WHITE}${BOLD}${step_title}${NC}"
    echo -e "  ${CYAN}╰──────────────────────────────────────────────────────────────────────────╯${NC}"
    echo ""
}

show_banner() {
    if command -v chafa &>/dev/null && [[ -f "$LOGO_IMG" ]]; then
        echo ""
        chafa --size 20x9 --symbols sextant+half+block+quad --colors full --color-space din99d --dither none --work 9 "$LOGO_IMG" 2>/dev/null || true
        echo -e "  ${BOLD}${WHITE}󰣇 𝗔𝗥𝗖𝗔𝗗𝗘-𝗢𝗦 𝗕𝗨𝗜𝗟𝗗 𝗘𝗡𝗚𝗜𝗡𝗘${NC}"
        echo -e "  ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo ""
        echo -e "  ${CYAN}${BOLD}󰣇  𝗔𝗥𝗖𝗔𝗗𝗘-𝗢𝗦 𝗕𝗨𝗜𝗟𝗗 𝗘𝗡𝗚𝗜𝗡𝗘${NC}"
        echo -e "  ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

show_info() {
    local version="2026.10.16"
    local pkg_count=0
    [[ -f "${PROFILE_DIR}/packages.x86_64" ]] && pkg_count=$(grep -vE '^\s*#|^\s*$' "${PROFILE_DIR}/packages.x86_64" | wc -l)
    
    local core_status="Unavailable"
    [[ -d "$CORE_REPO_DIR" ]] && core_status="Available"

    if command -v chafa &>/dev/null && [[ -f "$LOGO_IMG" ]]; then
        local img_cols=26
        local img_lines=13

        mapfile -t img < <(chafa --size "${img_cols}x${img_lines}" \
            --symbols sextant+half+block+quad \
            --colors full \
            --color-space din99d \
            --dither none \
            --work 9 \
            "$LOGO_IMG" 2>/dev/null)

        local -a info_lines=(
            "${CYAN}󰣇 𝗔𝗥𝗖𝗔𝗗𝗘-𝗢𝗦 @ 𝗟𝗜𝗡𝗨𝗫${NC}"
            "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            "${WHITE}󰣇 OS:${NC}        ${CYAN}Arcade Linux x86_64${NC}"
            "${WHITE}󰌽 Version:${NC}   ${GRAY}${version} (Rolling)${NC}"
            "${WHITE}󰧨 Desktop:${NC}   ${BLUE}KDE Plasma 6 (macOS Aesthetic)${NC}"
            "${WHITE}󰆍 Installer:${NC} ${GREEN}Calamares 3.4.2 (Arcade-Core)${NC}"
            "${WHITE}󰞷 Author:${NC}    ${WHITE}Abhinav Thakur <thakurabhinav22>${NC}"
            "${WHITE}󰋊 Profile:${NC}   ${DIM}${SCRIPT_DIR}${NC}"
            "${GRAY}──────────────────────────────────────${NC}"
            "${WHITE}󰘚 Packages:${NC}  ${pkg_count} base + desktop + utils"
            "${WHITE}󱑂 Core Repo:${NC} ${core_status}"
            "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
        echo -e "  ${CYAN}▄▄${NC}           ${WHITE}${BOLD}Arcade-OS${NC} ${CYAN}(v${version})${NC}"
        echo -e "  ${CYAN}████${NC}          ${WHITE}Abhinav Thakur${NC} ${DIM}<thakurabhinav22>${NC}"
        echo -e "  ${WHITE}Arch Linux x86_64 • KDE Plasma 6${NC}"
        echo -e "  ${GRAY}Calamares 3.4.2 • ${pkg_count} Packages${NC}"
        echo ""
    fi
}

info() {
    echo -e "  ${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "  ${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "  ${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "  ${RED}[ERROR]${NC} $1" >&2
}

usage() {
    echo -e "${BOLD}Usage:${NC} $0 [options]"
    echo ""
    echo "Options:"
    echo "  --info                Display Arcade-OS branding, system information, and specs"
    echo "  --clean               Clean previous build workspaces (work/ and out/)"
    echo "  --sync                Synchronize latest Calamares & Plasma configs from ArcadeLinux-Core"
    echo "  --run [iso]           Run the built ISO in QEMU"
    echo "    -m, --memory <RAM>  RAM size when running ISO (default: 4G)"
    echo "    -c, --cpu <CORES>   CPU cores when running ISO (default: 4)"
    echo "    --uefi              Force UEFI (OVMF) boot mode"
    echo "    --bios              Force Legacy BIOS boot mode (default)"
    echo "    --archiso           Run using run_archiso wrapper"
    echo "  --help                Show this help message"
    echo ""
    echo "Default action: Validates dependencies, updates pacman repo paths, and builds ISO."
}

check_dependencies() {
    step_header "Validating Build Environment & Dependencies"
    local missing=()
    for cmd in mkarchiso pacman repo-add; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required build tools: ${missing[*]}"
        error "Install them via: sudo pacman -S archiso"
        exit 1
    fi
    success "All build tools verified (archiso, pacman, repo-add, zstd)."
}

clean_workspace() {
    step_header "Cleaning Previous Build Workspaces"
    info "Purging work/ and out/ directories..."
    if [[ -d "$WORK_DIR" || -d "$OUT_DIR" || -d "${PROFILE_DIR}/work" || -d "${PROFILE_DIR}/out" ]]; then
        sudo rm -rf "$WORK_DIR" "$OUT_DIR" "${PROFILE_DIR}/work" "${PROFILE_DIR}/out"
        success "Cleaned previous workspaces."
    else
        info "Workspace is already clean."
    fi
}

sync_core() {
    step_header "Synchronizing Assets from ArcadeLinux-Core"
    if [[ -d "$CORE_REPO_DIR" ]]; then
        info "Source repository: ${CORE_REPO_DIR}"
        
        # Sync Calamares
        mkdir -p "${PROFILE_DIR}/airootfs/usr/share/calamares/branding/"
        cp -r "${CORE_REPO_DIR}/branding/arcade" "${PROFILE_DIR}/airootfs/usr/share/calamares/branding/"
        mkdir -p "${PROFILE_DIR}/airootfs/etc/calamares/"
        cp "${CORE_REPO_DIR}/settings.conf" "${PROFILE_DIR}/airootfs/etc/calamares/"
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
            success "Updated local package repository."
        fi
        success "Synced Calamares configurations and modules."
    else
        warn "ArcadeLinux-Core not found at ${CORE_REPO_DIR}. Skipping sync."
    fi
}

configure_pacman() {
    step_header "Configuring Pacman Repositories & Speed Optimizations"
    local conf="${PROFILE_DIR}/pacman.conf"
    
    if [[ -d "$LOCAL_REPO_DIR" ]]; then
        local local_pkg
        local_pkg=$(find "$LOCAL_REPO_DIR" -maxdepth 1 -name "calamares-*.pkg.tar.zst" 2>/dev/null | head -n 1)
        if [[ -n "$local_pkg" && ! -f "${LOCAL_REPO_DIR}/arcade-local.db.tar.gz" ]]; then
            info "Initializing arcade-local repository database..."
            (cd "$LOCAL_REPO_DIR" && repo-add -R "arcade-local.db.tar.gz" "$(basename "$local_pkg")")
        fi
    fi

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
    success "Configured [arcade-local] with absolute path resolvers."
}

build_iso() {
    step_header "Compiling Arcade Linux Bootable ISO"
    echo -e "  ${BOLD}Profile directory:${NC} ${PROFILE_DIR}"
    echo -e "  ${BOLD}Work directory:   ${NC} ${WORK_DIR}"
    echo -e "  ${BOLD}Output directory: ${NC} ${OUT_DIR}"
    echo ""

    if [[ -d "$WORK_DIR" ]]; then
        if [[ ! -f "${WORK_DIR}/iso/arch/x86_64/airootfs.sfs" || "$DO_CLEAN" == true ]]; then
            warn "Cleaning dirty workspace cache before build..."
            sudo rm -rf "$WORK_DIR"
        fi
    fi

    mkdir -p "$OUT_DIR"
    sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

    echo ""
    success "Arcade Linux ISO build finished successfully!"
    info "Generated image:"
    ls -lh "${OUT_DIR}/"*.iso 2>/dev/null || true
    echo ""
    info "You can test boot your ISO immediately with:"
    echo "  ./build.sh --run"
}

run_vm() {
    show_banner
    echo -e "  ${CYAN}${BOLD}▶ QEMU Virtual Machine Test Environment${NC}"
    echo -e "  ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local memory="4G"
    local cores="4"
    local runner="qemu"
    local boot_mode="bios"
    local target_iso=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--memory)
                memory="$2"
                shift 2
                ;;
            -c|--cpu)
                cores="$2"
                shift 2
                ;;
            --archiso)
                runner="archiso"
                shift
                ;;
            --uefi)
                boot_mode="uefi"
                shift
                ;;
            --bios)
                boot_mode="bios"
                shift
                ;;
            *.iso)
                target_iso="$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$target_iso" ]]; then
        target_iso=$(find "$OUT_DIR" -maxdepth 1 -name "*.iso" 2>/dev/null | sort -V | tail -n 1)
    fi

    if [[ -z "$target_iso" || ! -f "$target_iso" ]]; then
        error "No built ISO image found in ${OUT_DIR}/"
        echo ""
        echo "Please build the ISO first by running:"
        echo "  ./build.sh --clean"
        exit 1
    fi

    info "ISO Image:   $(basename "$target_iso")"
    info "Memory (RAM): ${memory}"
    info "CPU Cores:    ${cores}"

    if [[ "$runner" == "archiso" ]]; then
        if command -v run_archiso &>/dev/null; then
            info "Launching via run_archiso..."
            run_archiso -i "$target_iso"
            exit 0
        fi
    fi

    if ! command -v qemu-system-x86_64 &>/dev/null; then
        error "qemu-system-x86_64 not found. Install it via: sudo pacman -S qemu-desktop"
        exit 1
    fi

    local qemu_args=("-m" "$memory" "-smp" "$cores" "-cdrom" "$target_iso" "-boot" "d")

    if [[ -w /dev/kvm ]] || sudo -n test -w /dev/kvm 2>/dev/null; then
        qemu_args+=("-enable-kvm" "-cpu" "host")
        info "KVM Acceleration: ${GREEN}Enabled${NC}"
    else
        qemu_args+=("-cpu" "max")
        warn "KVM acceleration not permitted or unavailable. Running in software mode."
    fi

    qemu_args+=("-vga" "virtio" "-display" "gtk,gl=on")
    qemu_args+=("-audiodev" "pa,id=snd0" "-device" "intel-hda" "-device" "hda-duplex,audiodev=snd0")

    if [[ "$boot_mode" == "uefi" ]]; then
        local ovmf=""
        for p in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2-ovmf/x64/OVMF_CODE.fd /usr/share/ovmf/x64/OVMF_CODE.fd; do
            [[ -f "$p" ]] && { ovmf="$p"; break; }
        done
        if [[ -n "$ovmf" ]]; then
            qemu_args+=("-drive" "if=pflash,format=raw,readonly=on,file=${ovmf}")
            info "Boot Mode: UEFI (OVMF)"
        else
            warn "OVMF UEFI firmware not found on host. Defaulting to BIOS."
        fi
    else
        info "Boot Mode: BIOS (Legacy)"
    fi

    echo ""
    info "Launching virtual machine window..."
    if ! qemu-system-x86_64 "${qemu_args[@]}" 2>/dev/null; then
        # Fallback without gl=on
        warn "Direct OpenGL rendering failed. Launching standard GTK fallback..."
        qemu-system-x86_64 -m "$memory" -smp "$cores" -cdrom "$target_iso" -boot d -enable-kvm -vga virtio -display gtk
    fi
    success "Virtual machine session ended."
}

# ------------------------------------------------------------------------------
# Entrypoint
# ------------------------------------------------------------------------------

DO_CLEAN=false
DO_SYNC=false

for arg in "$@"; do
    if [[ "$arg" == "--info" ]]; then
        show_info
        exit 0
    elif [[ "$arg" == "--run" ]]; then
        run_vm "$@"
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

if [[ "$DO_CLEAN" == true ]]; then
    clean_workspace
fi

check_dependencies

if [[ "$DO_SYNC" == true ]]; then
    sync_core
fi

configure_pacman
build_iso
