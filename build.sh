#!/usr/bin/env bash
#
# build.sh — Build script for the Pomodoro macOS app
#
# Usage:
#   ./build.sh [command] [options]
#
# Commands:
#   generate   Regenerate the Xcode project from project.yml (xcodegen)
#   build      Build the app (default: Debug)
#   release    Build the app in Release configuration
#   clean      Clean build artifacts
#   run        Build (Debug) and launch the app
#   archive    Create a release archive (.xcarchive)
#   help       Show this help message
#
# Options:
#   --skip-gen   Skip xcodegen project generation before building
#
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="Pomodoro.xcodeproj"
SCHEME="Pomodoro"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_DIR="${BUILD_DIR}/archives"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Helpers ──────────────────────────────────────────────────────────────────

info()    { echo -e "${CYAN}▸${NC} $*"; }
success() { echo -e "${GREEN}✔${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
error()   { echo -e "${RED}✖${NC} $*" >&2; }

check_dep() {
    if ! command -v "$1" &>/dev/null; then
        error "$1 is not installed."
        echo "  Install with: $2"
        exit 1
    fi
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_generate() {
    info "Generating Xcode project from ${BOLD}project.yml${NC} …"
    check_dep xcodegen "brew install xcodegen"
    (cd "$PROJECT_DIR" && xcodegen generate)
    success "Project generated."
}

cmd_build() {
    local config="${1:-Debug}"
    local skip_gen="${2:-false}"

    if [[ "$skip_gen" != "true" ]]; then
        cmd_generate
    fi

    check_dep xcodebuild "Install Xcode from the App Store"

    info "Building ${BOLD}${SCHEME}${NC} (${config}) …"
    xcodebuild \
        -project "${PROJECT_DIR}/${PROJECT}" \
        -scheme "$SCHEME" \
        -configuration "$config" \
        -arch arm64 \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        build \
        | tail -5

    success "Build succeeded (${config})."

    local app_path
    app_path=$(find "${BUILD_DIR}/DerivedData/Build/Products/${config}" \
        -name "*.app" -maxdepth 1 2>/dev/null | head -1)
    if [[ -n "$app_path" ]]; then
        info "App bundle: ${BOLD}${app_path}${NC}"
    fi
}

cmd_release() {
    cmd_build "Release" "${1:-false}"
}

cmd_clean() {
    info "Cleaning build artifacts …"

    if [[ -d "${BUILD_DIR}" ]]; then
        rm -rf "${BUILD_DIR}"
        success "Removed ${BUILD_DIR}"
    fi

    # Also clean Xcode's derived data for this project
    xcodebuild \
        -project "${PROJECT_DIR}/${PROJECT}" \
        -scheme "$SCHEME" \
        -arch arm64 \
        clean 2>/dev/null || true

    success "Clean complete."
}

cmd_run() {
    local skip_gen="${1:-false}"
    cmd_build "Debug" "$skip_gen"

    local app_path
    app_path=$(find "${BUILD_DIR}/DerivedData/Build/Products/Debug" \
        -name "*.app" -maxdepth 1 2>/dev/null | head -1)

    if [[ -z "$app_path" ]]; then
        error "Could not find built .app bundle."
        exit 1
    fi

    info "Launching ${BOLD}$(basename "$app_path")${NC} …"
    open "$app_path"
}

cmd_archive() {
    local skip_gen="${1:-false}"

    if [[ "$skip_gen" != "true" ]]; then
        cmd_generate
    fi

    check_dep xcodebuild "Install Xcode from the App Store"

    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local archive_path="${ARCHIVE_DIR}/Pomodoro_${timestamp}.xcarchive"

    mkdir -p "$ARCHIVE_DIR"

    info "Archiving ${BOLD}${SCHEME}${NC} …"
    xcodebuild \
        -project "${PROJECT_DIR}/${PROJECT}" \
        -scheme "$SCHEME" \
        -configuration Release \
        -arch arm64 \
        -archivePath "$archive_path" \
        archive \
        | tail -5

    success "Archive created: ${BOLD}${archive_path}${NC}"
}

cmd_help() {
    echo -e "${BOLD}🍅 Pomodoro Build Script${NC}"
    echo ""
    echo "Usage: ./build.sh [command] [options]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  generate       Regenerate Xcode project from project.yml"
    echo "  build          Build the app (Debug configuration)"
    echo "  release        Build the app (Release configuration)"
    echo "  clean          Clean all build artifacts"
    echo "  run            Build and launch the app"
    echo "  archive        Create a release .xcarchive"
    echo "  help           Show this help message"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  --skip-gen     Skip xcodegen project generation"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./build.sh                  # generate + build (Debug)"
    echo "  ./build.sh run              # generate + build + launch"
    echo "  ./build.sh release          # generate + build (Release)"
    echo "  ./build.sh build --skip-gen # build without regenerating project"
    echo "  ./build.sh clean            # remove build artifacts"
    echo "  ./build.sh archive          # create a release archive"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    local command="${1:-build}"
    shift 2>/dev/null || true

    # Parse options
    local skip_gen="false"
    for arg in "$@"; do
        case "$arg" in
            --skip-gen) skip_gen="true" ;;
            *)
                error "Unknown option: $arg"
                cmd_help
                exit 1
                ;;
        esac
    done

    case "$command" in
        generate)  cmd_generate ;;
        build)     cmd_build "Debug" "$skip_gen" ;;
        release)   cmd_release "$skip_gen" ;;
        clean)     cmd_clean ;;
        run)       cmd_run "$skip_gen" ;;
        archive)   cmd_archive "$skip_gen" ;;
        help|-h|--help) cmd_help ;;
        *)
            error "Unknown command: $command"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
