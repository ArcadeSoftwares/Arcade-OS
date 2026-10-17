#!/usr/bin/env bash
# ==============================================================================
# Arcade-OS ISO Runner (run.sh)
# Boots the built Arcade Linux ISO in QEMU with hardware acceleration and UEFI/BIOS support
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/out"

# ANSI Colors
CYAN='\033[38;5;51m'
BLUE='\033[38;5;39m'
GREEN='\033[38;5;48m'
YELLOW='\033[38;5;220m'
RED='\033[38;5;196m'
WHITE='\033[38;5;255m'
BOLD='\033[1m'
NC='\033[0m'

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

find_iso() {
    local iso
    iso=$(find "$OUT_DIR" -maxdepth 1 -name "*.iso" 2>/dev/null | sort -V | tail -n 1)
    if [[ -z "$iso" || ! -f "$iso" ]]; then
        error "No ISO found in ${OUT_DIR}/"
        echo ""
        echo "Please build the ISO first by running:"
        echo "  ./build.sh"
        exit 1
    fi
    echo "$iso"
}

usage() {
    echo -e "${BOLD}Usage:${NC} $0 [options] [path_to_iso]"
    echo ""
    echo "Options:"
    echo "  -m, --memory <RAM>     RAM size (default: 4G)"
    echo "  -c, --cpu <CORES>      Number of CPU cores (default: 4)"
    echo "  --archiso              Run using run_archiso wrapper (archiso default runner)"
    echo "  --uefi                 Force UEFI mode (OVMF)"
    echo "  --bios                 Force Legacy BIOS mode (default)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     # Run newest built ISO with 4G RAM & 4 cores"
    echo "  $0 -m 8G -c 6          # Run with custom RAM/CPU"
    echo "  $0 --archiso           # Run with run_archiso"
    echo "  $0 path/to/image.iso   # Run a specific ISO file"
}

MEMORY="4G"
CORES="4"
RUNNER="qemu"
BOOT_MODE="auto"
TARGET_ISO=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--memory)
            MEMORY="$2"
            shift 2
            ;;
        -c|--cpu)
            CORES="$2"
            shift 2
            ;;
        --archiso)
            RUNNER="archiso"
            shift
            ;;
        --uefi)
            BOOT_MODE="uefi"
            shift
            ;;
        --bios)
            BOOT_MODE="bios"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *.iso)
            TARGET_ISO="$1"
            shift
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$TARGET_ISO" ]]; then
    TARGET_ISO=$(find_iso)
fi

if [[ ! -f "$TARGET_ISO" ]]; then
    error "Specified ISO file does not exist: $TARGET_ISO"
    exit 1
fi

echo -e "${CYAN}${BOLD}▶ Starting Arcade Linux Virtual Machine${NC}"
echo -e "  ${WHITE}ISO:${NC}    $(basename "$TARGET_ISO") (${TARGET_ISO})"
echo -e "  ${WHITE}Memory:${NC} ${MEMORY}"
echo -e "  ${WHITE}Cores:${NC}  ${CORES}"
echo ""

# Runner: run_archiso
if [[ "$RUNNER" == "archiso" ]]; then
    if command -v run_archiso &>/dev/null; then
        info "Launching via run_archiso..."
        run_archiso -i "$TARGET_ISO"
        exit 0
    else
        warn "run_archiso command not found. Falling back to native QEMU..."
    fi
fi

# Runner: native QEMU
if ! command -v qemu-system-x86_64 &>/dev/null; then
    error "qemu-system-x86_64 is not installed. Please install QEMU:"
    error "  sudo pacman -S qemu-desktop"
    exit 1
fi

# Detect KVM hardware acceleration
QEMU_ARGS=("-m" "$MEMORY" "-smp" "$CORES" "-cdrom" "$TARGET_ISO" "-boot" "d")

if [[ -w /dev/kvm ]] || sudo -n test -w /dev/kvm 2>/dev/null; then
    QEMU_ARGS+=("-enable-kvm" "-cpu" "host")
    info "KVM hardware acceleration: ${GREEN}Enabled${NC}"
else
    QEMU_ARGS+=("-cpu" "max")
    warn "KVM acceleration unavailable or insufficient permissions (/dev/kvm). Running in emulation mode."
fi

# Video & Display
QEMU_ARGS+=("-vga" "virtio" "-display" "gtk,gl=on")

# Sound
QEMU_ARGS+=("-audiodev" "pa,id=snd0" "-device" "intel-hda" "-device" "hda-duplex,audiodev=snd0")

# UEFI / BIOS mode handling
if [[ "$BOOT_MODE" == "uefi" || "$BOOT_MODE" == "auto" ]]; then
    OVMF_CODE=""
    for p in /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2-ovmf/x64/OVMF_CODE.fd /usr/share/ovmf/x64/OVMF_CODE.fd; do
        if [[ -f "$p" ]]; then
            OVMF_CODE="$p"
            break
        fi
    done

    if [[ -n "$OVMF_CODE" && "$BOOT_MODE" == "uefi" ]]; then
        QEMU_ARGS+=("-drive" "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}")
        info "Boot Mode: ${CYAN}UEFI (OVMF)${NC}"
    else
        info "Boot Mode: ${CYAN}BIOS (Legacy)${NC}"
    fi
fi

info "Launching QEMU window..."
if qemu-system-x86_64 "${QEMU_ARGS[@]}" 2>/dev/null; then
    success "Virtual machine session ended."
else
    # Fallback without gl=on in case host GPU driver doesn't support OpenGL in GTK
    warn "First launch attempt failed. Retrying with standard fallback display settings..."
    qemu-system-x86_64 -m "$MEMORY" -smp "$CORES" -cdrom "$TARGET_ISO" -boot d -enable-kvm -vga virtio -display gtk
fi
