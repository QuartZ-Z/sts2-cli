#!/usr/bin/env bash
# Copy game DLLs, apply the shared Sts2Patcher, and build sts2-cli.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

VALIDATE_ONLY=0
if [[ "${1:-}" == "--validate-only" ]]; then
    VALIDATE_ONLY=1
    shift
fi

GAME_DIR="${1:-${STS2_GAME_DIR:-}}"
if [[ -z "$GAME_DIR" ]]; then
    case "$(uname -s)" in
        Darwin)
            GAME_DIR="$HOME/Library/Application Support/Steam/steamapps/common/Slay the Spire 2/SlayTheSpire2.app/Contents/Resources/data_sts2_macos_arm64"
            if [[ ! -d "$GAME_DIR" ]]; then
                GAME_DIR="$HOME/Library/Application Support/Steam/steamapps/common/Slay the Spire 2/SlayTheSpire2.app/Contents/Resources/data_sts2_macos_x86_64"
            fi
            ;;
        Linux)
            GAME_DIR="$HOME/.steam/steam/steamapps/common/Slay the Spire 2"
            if [[ ! -d "$GAME_DIR" ]]; then
                GAME_DIR="$HOME/.local/share/Steam/steamapps/common/Slay the Spire 2"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            GAME_DIR="C:/Program Files (x86)/Steam/steamapps/common/Slay the Spire 2"
            ;;
    esac
fi

if [[ ! -d "$GAME_DIR" ]]; then
    echo "Game directory not found: ${GAME_DIR:-<not configured>}" >&2
    echo "Usage: ./setup.sh [--validate-only] /path/to/game/data" >&2
    exit 1
fi

DOTNET="${DOTNET:-}"
if [[ -z "$DOTNET" && -x "$HOME/.dotnet-arm64/dotnet" ]]; then
    DOTNET="$HOME/.dotnet-arm64/dotnet"
elif [[ -z "$DOTNET" ]] && command -v dotnet >/dev/null 2>&1; then
    DOTNET="dotnet"
fi
if [[ -z "$DOTNET" ]]; then
    echo ".NET 9 SDK not found. Install it or set DOTNET." >&2
    exit 1
fi
if ! "$DOTNET" --list-sdks | grep -q '^9\.'; then
    echo ".NET 9 SDK not found. Newer major versions alone are not supported." >&2
    exit 1
fi

DLLS=(
    "sts2.dll"
    "SmartFormat.dll"
    "SmartFormat.ZString.dll"
    "Sentry.dll"
    "Steamworks.NET.dll"
    "MonoMod.Backports.dll"
    "MonoMod.ILHelpers.dll"
    "0Harmony.dll"
    "System.IO.Hashing.dll"
)

find_dll() {
    local dll="$1"
    if [[ -f "$GAME_DIR/$dll" ]]; then
        printf '%s\n' "$GAME_DIR/$dll"
    else
        find "$GAME_DIR" -name "$dll" -type f -print -quit 2>/dev/null
    fi
}

echo "Game directory: $GAME_DIR"
echo ".NET SDK: $DOTNET ($("$DOTNET" --version))"

if [[ "$VALIDATE_ONLY" -eq 1 ]]; then
    missing=0
    for dll in "${DLLS[@]}"; do
        if [[ -n "$(find_dll "$dll")" ]]; then
            echo "  OK $dll"
        else
            echo "  MISSING $dll"
            missing=1
        fi
    done
    if [[ "$missing" -ne 0 ]]; then
        echo "Validation failed: required game DLLs are missing." >&2
        exit 1
    fi
    echo "Validation passed. No files were changed."
    exit 0
fi

mkdir -p lib
echo "Copying game DLLs..."
for dll in "${DLLS[@]}"; do
    source_path="$(find_dll "$dll")"
    if [[ -n "$source_path" ]]; then
        cp "$source_path" "lib/$dll"
        echo "  OK $dll"
    else
        echo "  WARNING $dll was not found"
    fi
done

if [[ ! -f "lib/sts2.dll" ]]; then
    echo "sts2.dll could not be copied from $GAME_DIR." >&2
    exit 1
fi
if [[ ! -f "lib/sts2.dll.original" ]]; then
    cp "lib/sts2.dll" "lib/sts2.dll.original"
fi

echo "Applying headless IL patches..."
"$DOTNET" run --project src/Sts2Patcher/Sts2Patcher.csproj -- "$ROOT/lib/sts2.dll"

echo "Building sts2-cli..."
"$DOTNET" build src/Sts2Headless/Sts2Headless.csproj

echo "Setup complete."
echo "To play: python3 python/play.py"
