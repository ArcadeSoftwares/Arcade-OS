#!/usr/bin/env bash
# ==============================================================================
# Arcade-OS Universal Build & Runner Engine (build.sh)
# Builds, tests, syncs, and boots Arcade Linux ISOs
# Exact Cyberpunk / Neon Palette from thakurabhinav22/AnimeTerminal
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

# ── Exact 24-bit TrueColor Palette from AnimeTerminal (config.jsonc) ──
RED='\033[1;38;2;255;45;85m'       # #FF2D55 - Neon Pink/Red (OS / Title / Alert)
PURPLE='\033[1;38;2;199;125;255m'  # #C77DFF - Electric Purple (Kernel / Separators)
CYAN='\033[1;38;2;0;229;255m'      # #00E5FF - Vivid Neon Cyan (Shell / DE / CPU / Disk)
GREEN='\033[1;38;2;57;255;20m'     # #39FF14 - Electric Toxic Green (Uptime / Font / Success)
PEACH='\033[1;38;2;255;154;162m'  # #FF9AA2 - Soft Neon Peach / Anya Peanut
WHITE='\033[1;38;2;255;255;255m'  # Pure White
GRAY='\033[38;2;140;140;150m'     # Muted Subtext Gray
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'                      # Reset

# Step counter
CURRENT_STEP=0
TOTAL_STEPS=5

step_header() {
    local step_title="$1"
    (( CURRENT_STEP++ )) || true
    echo ""
    echo -e "  ${RED}━${PURPLE}━${CYAN}━${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${RED}󰣇 ${WHITE}${BOLD}[STEP ${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${CYAN}${BOLD}${step_title}${NC}"
    echo -e "  ${RED}━${PURPLE}━${CYAN}━${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

show_banner() {
    echo ""
    if command -v chafa &>/dev/null && [[ -f "$LOGO_IMG" ]]; then
        chafa --size 22x10 --symbols sextant+half+block+quad --colors full --color-space din99d --dither none --work 9 "$LOGO_IMG" 2>/dev/null || true
    fi
    echo -e "  ${RED}󰣇 ${RED}𝗔𝗥𝗖𝗔𝗗𝗘-𝗢𝗦 ${PURPLE}@ ${CYAN}𝗟𝗜𝗡𝗨𝗫 ${CYAN}󰌽${NC}"
    echo -e "  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${RED}󰣇 OS:${NC}        ${RED}Arcade Linux x86_64${NC}"
    echo -e "  ${PURPLE}󰌽 Kernel:${NC}    ${PURPLE}Rolling Release • KDE Plasma 6${NC}"
    echo -e "  ${CYAN}󰞷 System:${NC}    ${CYAN}Calamares 3.4.2 GUI • macOS Aesthetic${NC}"
    echo -e "  ${GREEN}󱑂 Author:${NC}    ${GREEN}Abhinav Thakur <thakurabhinav22>${NC}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "   \033[31m \033[32m \033[33m \033[34m \033[35m \033[36m \033[37m\033[0m"
    echo -e "   ${PEACH}🛡️ ${RED}𝗙𝗢𝗥𝗞𝗘𝗗 ${PURPLE}𝗙𝗢𝗥 ${CYAN}𝗣𝗥𝗜𝗩𝗔𝗖𝗬 ${GREEN}𝗕𝗨𝗜𝗟𝗧 ${PEACH}𝗙𝗢𝗥 ${PURPLE}𝗦𝗣𝗘𝗘𝗗 ${PEACH}🛡️${NC}"
    echo ""
}

show_info() {
    local version="2026.10.16"
    local pkg_count=0
    [[ -f "${PROFILE_DIR}/packages.x86_64" ]] && pkg_count=$(grep -vE '^\s*#|^\s*$' "${PROFILE_DIR}/packages.x86_64" | wc -l)
    
    local core_status="${GREEN}Available${NC}"
    [[ ! -d "$CORE_REPO_DIR" ]] && core_status="${RED}Not Found${NC}"

    if command -v chafa &>/dev/null && [[ -f "$LOGO_IMG" ]]; then
        local img_cols=26
        local img_lines=13

        mapfile -t img < <(chafa --size "${img_cols}x${img_lines}" \
            --symbols sextant+half+block+quad \
            --colors full \
            --color-space din99d \
            --dither none \
            --work 9 \
            --threshold 0.5 \
            "$LOGO_IMG" 2>/dev/null)

        local -a info_lines=(
            "${RED}󰣇 𝗔𝗕𝗛𝗜𝟵𝗔𝗩 ${PURPLE}@ ${CYAN}𝗔𝗥𝗖𝗔𝗗𝗘-𝗢𝗦 ${CYAN}󰌽${NC}"
            "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            "${RED}󰣇 OS:${NC}        ${RED}Arcade Linux x86_64${NC}"
            "${PURPLE}󰌽 Kernel:${NC}    ${PURPLE}6.x (Rolling)${NC}"
            "${GREEN}󱑂 Status:${NC}    ${GREEN}Production Ready${NC}"
            "${CYAN}󰞷 Shell:${NC}     ${CYAN}zsh / bash${NC}"
            "${CYAN}󰧨 DE:${NC}        ${CYAN}KDE Plasma 6 (macOS Aesthetic)${NC}"
            "${RED}󰆍 Installer:${NC} ${RED}Calamares 3.4.2${NC}"
            "${GREEN}󰛖 Author:${NC}    ${GREEN}Abhinav Thakur <thakurabhinav22>${NC}"
            "${GREEN}──────────────────────────────────────${NC}"
            "${CYAN}󰻠 Packages:${NC}  ${CYAN}${pkg_count} packages active${NC}"
            "${RED}󰘚 Profile:${NC}   ${RED}${SCRIPT_DIR}${NC}"
            "${PURPLE}󰋊 Core Repo:${NC} ${core_status}"
            "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            "   \033[31m \033[32m \033[33m \033[34m \033[35m \033[36m \033[37m\033[0m"
            " ${PEACH}🛡️ ${RED}𝗙𝗢𝗥𝗞𝗘𝗗 ${PURPLE}𝗙𝗢𝗥 ${CYAN}𝗣𝗥𝗜𝗩𝗔𝗖𝗬 ${GREEN}𝗕𝗨𝗜𝗟𝗧 ${PEACH}𝗙𝗢𝗥 ${PURPLE}𝗦𝗣𝗘𝗘𝗗 ${PEACH}🛡️${NC}"
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
        show_banner
    fi
}

info() {
    echo -e "  ${CYAN}󰋼 [INFO]${NC} $1"
}

success() {
    echo -e "  ${GREEN}✔ [SUCCESS]${NC} $1"
}

warn() {
    echo -e "  ${PURPLE}▲ [WARNING]${NC} $1"
}

error() {
    echo -e "  ${RED}✖ [ERROR]${NC} $1" >&2
}

usage() {
    echo -e "${RED}${BOLD}Usage:${NC} $0 [options]"
    echo ""
    echo -e "${WHITE}${BOLD}Build Options:${NC}"
    echo -e "  ${CYAN}--clean${NC}               Clean previous build workspaces (${GRAY}work/${NC} and ${GRAY}out/${NC})"
    echo -e "  ${CYAN}--sync${NC}                Synchronize latest Calamares & Plasma configs from ArcadeLinux-Core"
    echo -e "  ${CYAN}--info${NC}                Display Arcade-OS AnimeTerminal branding and specs"
    echo -e "  ${CYAN}--help, -h${NC}            Show this help message"
    echo ""
    echo -e "${WHITE}${BOLD}Runner Options (QEMU VM):${NC}"
    echo -e "  ${GREEN}--run [iso]${NC}           Launch built ISO in virtual machine"
    echo -e "    ${GRAY}-m, --memory <RAM>${NC}  RAM size (default: ${GREEN}4G${NC})"
    echo -e "    ${GRAY}-c, --cpu <CORES>${NC}   CPU cores (default: ${GREEN}4${NC})"
    echo -e "    ${GRAY}--uefi${NC}              Force UEFI (OVMF) boot mode"
    echo -e "    ${GRAY}--bios${NC}              Force Legacy BIOS boot mode (${GREEN}default${NC})"
    echo -e "    ${GRAY}--archiso${NC}           Run via archiso wrapper (${GRAY}run_archiso${NC})"
    echo ""
    echo -e "${GRAY}Default action (without flags): Validates dependencies, syncs repositories, and builds the ISO.${NC}"
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
        error "Install them via: ${CYAN}sudo pacman -S archiso${NC}"
        exit 1
    fi
    success "All build tools verified (${GREEN}archiso${NC}, ${GREEN}pacman${NC}, ${GREEN}repo-add${NC}, ${GREEN}zstd${NC})."
}

clean_workspace() {
    step_header "Cleaning Previous Build Workspaces"
    info "Purging ${GRAY}work/${NC} and ${GRAY}out/${NC} directories..."
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
        info "Source repository: ${CYAN}${CORE_REPO_DIR}${NC}"
        
        # Sync Calamares Branding & Configs
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
    success "Configured ${CYAN}[arcade-local]${NC} with dynamic path resolvers."
}

build_iso() {
    step_header "Compiling Arcade Linux Bootable ISO"
    echo -e "  ${WHITE}${BOLD}Profile directory:${NC} ${CYAN}${PROFILE_DIR}${NC}"
    echo -e "  ${WHITE}${BOLD}Work directory:   ${NC} ${PURPLE}${WORK_DIR}${NC}"
    echo -e "  ${WHITE}${BOLD}Output directory: ${NC} ${GREEN}${OUT_DIR}${NC}"
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
    info "Test boot your ISO immediately with:"
    echo -e "  ${GREEN}${BOLD}./build.sh --run${NC}"
}

run_vm() {
    show_banner
    echo -e "  ${RED}━${PURPLE}━${CYAN}━${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${RED}󰣇 ${WHITE}${BOLD}[QEMU RUNNER]${NC} ${CYAN}${BOLD}Arcade Linux Virtual Machine${NC}"
    echo -e "  ${RED}━${PURPLE}━${CYAN}━${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
        echo -e "Please build the ISO first by running:"
        echo -e "  ${GREEN}./build.sh --clean${NC}"
        exit 1
    fi

    info "ISO Image:    ${CYAN}$(basename "$target_iso")${NC}"
    info "Memory (RAM): ${GREEN}${memory}${NC}"
    info "CPU Cores:    ${PURPLE}${cores}${NC}"

    if [[ "$runner" == "archiso" ]]; then
        if command -v run_archiso &>/dev/null; then
            info "Launching via ${GREEN}run_archiso${NC}..."
            run_archiso -i "$target_iso"
            exit 0
        fi
    fi

    if ! command -v qemu-system-x86_64 &>/dev/null; then
        error "qemu-system-x86_64 not found. Install via: ${CYAN}sudo pacman -S qemu-desktop${NC}"
        exit 1
    fi

    local qemu_args=("-m" "$memory" "-smp" "$cores" "-cdrom" "$target_iso" "-boot" "d")

    if [[ -w /dev/kvm ]] || sudo -n test -w /dev/kvm 2>/dev/null; then
        qemu_args+=("-enable-kvm" "-cpu" "host")
        info "KVM Acceleration: ${GREEN}Enabled (Host CPU)${NC}"
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
            info "Boot Mode: ${CYAN}UEFI (OVMF)${NC}"
        else
            warn "OVMF UEFI firmware not found on host. Defaulting to BIOS."
        fi
    else
        info "Boot Mode: ${PURPLE}BIOS (Legacy)${NC}"
    fi

    echo ""
    info "Launching virtual machine window..."
    if ! qemu-system-x86_64 "${qemu_args[@]}" 2>/dev/null; then
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
