#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Alexandros Theodotou <alex@zrythm.org>
# SPDX-License-Identifier: LicenseRef-ZrythmLicense
#
# Download and install recommended free (gratis, open source) plugins into the
# per-user plugin directories that Zrythm scans by default.
#
# Supported plugins (all cross-platform VST3, most also CLAP/LV2):
#   surge    Surge XT synthesizer (GPL-3.0) — VST3/CLAP/LV2
#   dexed    Dexed FM synthesizer, DX7-compatible (GPL-3.0) — VST3
#   odin2    Odin 2 synthesizer (GPL-3.0) — VST3/LV2
#   byod     BYOD guitar distortion effect (GPL-3.0) — VST3/LV2
#   cardinal Cardinal modular synth (GPL-3.0) — VST3/CLAP/LV2 (large download)
#
# Usage:
#   tools/fetch_free_plugins.sh                 # install all except cardinal
#   tools/fetch_free_plugins.sh surge dexed     # install only these
#   tools/fetch_free_plugins.sh --list          # list supported plugins
#
# Notes:
# - Windows installer packages (.exe/.pkg) are downloaded to the destination
#   directory and must be run manually; archive formats are installed
#   automatically.
# - Requires: curl, unzip, tar. On Linux, `ar` is needed for .deb packages
#   (provided by binutils).

set -euo pipefail

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

ALL_PLUGINS=(surge dexed odin2 byod cardinal)

if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' "${ALL_PLUGINS[@]}"
  exit 0
fi

if [[ $# -gt 0 ]]; then
  PLUGINS=("$@")
else
  # cardinal is a ~1 GB download; opt-in only
  PLUGINS=(surge dexed odin2 byod)
fi

for p in "${PLUGINS[@]}"; do
  case " ${ALL_PLUGINS[*]} " in
    *" $p "*) ;;
    *) die "unknown plugin '$p' (use --list)" ;;
  esac
done

for tool in curl unzip tar; do
  command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done

case "$(uname -s)" in
  Linux*)
    OS=linux
    VST3_DIR="$HOME/.vst3"
    CLAP_DIR="$HOME/.clap"
    LV2_DIR="$HOME/.lv2"
    ;;
  Darwin*)
    OS=macos
    VST3_DIR="$HOME/Library/Audio/Plug-Ins/VST3"
    CLAP_DIR="$HOME/Library/Audio/Plug-Ins/CLAP"
    LV2_DIR="$HOME/Library/Audio/Plug-Ins/LV2"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    OS=windows
    VST3_DIR="${PROGRAMFILES:-/c/Program Files}/Common Files/VST3"
    CLAP_DIR="${PROGRAMFILES:-/c/Program Files}/Common Files/CLAP"
    LV2_DIR=
    ;;
  *) die "unsupported OS: $(uname -s)" ;;
esac

INSTALLER_DIR="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}/zrythm-free-plugins"
mkdir -p "$VST3_DIR" "$CLAP_DIR" "$INSTALLER_DIR"
[[ -n "${LV2_DIR:-}" ]] && mkdir -p "$LV2_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Print the download URL of the latest-release asset whose name matches the
# given grep pattern. $1 = owner/repo, $2 = extended-regex pattern.
latest_asset_url() {
  local repo="$1" pattern="$2" url
  url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*"' \
    | cut -d'"' -f4 \
    | grep -E -- "$pattern" \
    | head -n1)"
  [[ -n "$url" ]] || die "no asset matching '${pattern}' in ${repo} latest release"
  printf '%s' "$url"
}

download() {
  local url="$1" out="$2"
  log "downloading $url"
  curl -fSL --retry 3 -o "$out" "$url"
}

# Install all plugin bundles found below $1 into the per-user plugin dirs.
install_bundles() {
  local root="$1" found=0 bundle base
  while IFS= read -r -d '' bundle; do
    base="$(basename "$bundle")"
    found=1
    case "$base" in
      *.vst3) cp -a "$bundle" "$VST3_DIR/" ;;
      *.clap) cp -a "$bundle" "$CLAP_DIR/" ;;
      *.lv2)
        if [[ -n "${LV2_DIR:-}" ]]; then
          cp -a "$bundle" "$LV2_DIR/"
        else
          continue
        fi
        ;;
      *) continue ;;
    esac
    log "installed $base"
  done < <(find "$root" \( -name '*.vst3' -o -name '*.clap' -o -name '*.lv2' \) -print0)
  [[ "$found" == 1 ]] || warn "no plugin bundles found in $root"
}

# Save an installer package the user must run manually.
stash_installer() {
  local file="$1"
  mv "$file" "$INSTALLER_DIR/"
  warn "run the installer manually: $INSTALLER_DIR/$(basename "$file")"
}

fetch_surge() {
  local url file
  case "$OS" in
    linux)   url="$(latest_asset_url surge-synthesizer/surge 'linux-x86_64.*pluginsonly\.tar\.gz$|linux-NIGHTLY.*pluginsonly\.tar\.gz$')" ;;
    macos)   url="$(latest_asset_url surge-synthesizer/surge 'macos.*pluginsonly\.zip$')" ;;
    windows) url="$(latest_asset_url surge-synthesizer/surge 'win64-NIGHTLY.*pluginsonly\.zip$')" ;;
  esac
  file="$TMP_DIR/surge_pkg"
  download "$url" "$file"
  mkdir -p "$TMP_DIR/surge"
  case "$url" in
    *.tar.gz) tar -xzf "$file" -C "$TMP_DIR/surge" ;;
    *.zip)    unzip -q "$file" -d "$TMP_DIR/surge" ;;
  esac
  install_bundles "$TMP_DIR/surge"
}

fetch_dexed() {
  local url file
  case "$OS" in
    linux)   url="$(latest_asset_url asb2m10/dexed '-lnx\.zip$')" ;;
    macos)   url="$(latest_asset_url asb2m10/dexed '-macOS\.zip$')" ;;
    windows) url="$(latest_asset_url asb2m10/dexed '-win\.zip$')" ;;
  esac
  file="$TMP_DIR/dexed.zip"
  download "$url" "$file"
  mkdir -p "$TMP_DIR/dexed"
  unzip -q "$file" -d "$TMP_DIR/dexed"
  install_bundles "$TMP_DIR/dexed"
}

fetch_odin2() {
  local url file
  case "$OS" in
    linux)   url="$(latest_asset_url TheWaveWarden/odin2 'Linux\.zip$')" ;;
    macos)   url="$(latest_asset_url TheWaveWarden/odin2 'MacInstaller\.pkg$')" ;;
    windows) url="$(latest_asset_url TheWaveWarden/odin2 'WinInstaller\.exe$')" ;;
  esac
  file="$TMP_DIR/odin2_${url##*/}"
  download "$url" "$file"
  case "$url" in
    *.zip)
      mkdir -p "$TMP_DIR/odin2"
      unzip -q "$file" -d "$TMP_DIR/odin2"
      install_bundles "$TMP_DIR/odin2"
      ;;
    *) stash_installer "$file" ;;
  esac
}

fetch_byod() {
  local url file
  case "$OS" in
    linux)   url="$(latest_asset_url Chowdhury-DSP/BYOD 'Linux-x64.*\.deb$')" ;;
    macos)   url="$(latest_asset_url Chowdhury-DSP/BYOD '-Mac-.*\.dmg$')" ;;
    windows) url="$(latest_asset_url Chowdhury-DSP/BYOD '-Win-64bit-.*\.exe$')" ;;
  esac
  file="$TMP_DIR/byod_${url##*/}"
  download "$url" "$file"
  case "$url" in
    *.deb)
      command -v ar >/dev/null 2>&1 || die "extracting .deb requires 'ar' (binutils)"
      mkdir -p "$TMP_DIR/byod"
      (cd "$TMP_DIR/byod" && ar x "$file" && tar -xf data.tar.*)
      install_bundles "$TMP_DIR/byod"
      ;;
    *) stash_installer "$file" ;;
  esac
}

fetch_cardinal() {
  local url file
  case "$OS" in
    linux)   url="$(latest_asset_url DISTRHO/Cardinal 'linux-x86_64-.*\.tar\.gz$')" ;;
    macos)   url="$(latest_asset_url DISTRHO/Cardinal 'macOS-universal-.*\.pkg$')" ;;
    windows) url="$(latest_asset_url DISTRHO/Cardinal 'win64-.*\.zip$')" ;;
  esac
  file="$TMP_DIR/cardinal_${url##*/}"
  download "$url" "$file"
  case "$url" in
    *.tar.gz)
      mkdir -p "$TMP_DIR/cardinal"
      tar -xzf "$file" -C "$TMP_DIR/cardinal"
      install_bundles "$TMP_DIR/cardinal"
      ;;
    *.zip)
      mkdir -p "$TMP_DIR/cardinal"
      unzip -q "$file" -d "$TMP_DIR/cardinal"
      install_bundles "$TMP_DIR/cardinal"
      ;;
    *) stash_installer "$file" ;;
  esac
}

log "installing plugins for $OS"
log "VST3 dir: $VST3_DIR"
log "CLAP dir: $CLAP_DIR"
[[ -n "${LV2_DIR:-}" ]] && log "LV2 dir:  $LV2_DIR"

for p in "${PLUGINS[@]}"; do
  log "fetching $p"
  "fetch_$p"
done

log "done — rescan plugins in Zrythm to pick them up"
