#!/usr/bin/env bash

set -euo pipefail

MODE="check"
AUTO_YES=0
FAIL_ON_MISSING=0

usage() {
    cat <<'EOF'
Uso:
  preflight-kit.sh [--install] [--yes] [--fail-on-missing]

Descripcion:
  Comprueba requisitos del kit para trabajar con .elpx en distintos entornos.
  Por defecto solo informa (no instala y no falla por faltantes).

Opciones:
  --install          Intenta instalar dependencias faltantes cuando sea posible.
  --yes              No pide confirmacion interactiva.
  --fail-on-missing  Devuelve codigo != 0 si faltan dependencias requeridas.
  -h, --help         Muestra esta ayuda.
EOF
}

say() {
    printf '%s\n' "$1"
}

ok() {
    printf '[OK] %s\n' "$1"
}

warn() {
    printf '[WARN] %s\n' "$1"
}

fail() {
    printf '[FAIL] %s\n' "$1"
}

confirm() {
    local prompt="$1"
    local ans
    if [[ "$AUTO_YES" -eq 1 ]]; then
        return 0
    fi
    printf '%s [y/N]: ' "$prompt"
    read -r ans || true
    [[ "$ans" =~ ^[Yy]$ ]]
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

detect_runtime_platform() {
    local uname_s
    uname_s="$(uname -s 2>/dev/null || echo unknown)"
    case "$uname_s" in
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin) echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows-bash" ;;
        *) echo "unknown" ;;
    esac
}

detect_pkg_manager() {
    if have_cmd apt-get; then echo "apt"; return; fi
    if have_cmd dnf; then echo "dnf"; return; fi
    if have_cmd yum; then echo "yum"; return; fi
    if have_cmd pacman; then echo "pacman"; return; fi
    if have_cmd zypper; then echo "zypper"; return; fi
    if have_cmd apk; then echo "apk"; return; fi
    if have_cmd brew; then echo "brew"; return; fi
    if have_cmd winget; then echo "winget"; return; fi
    if have_cmd choco; then echo "choco"; return; fi
    echo "none"
}

pkg_for_cmd() {
    local manager="$1"
    local cmd="$2"

    case "$manager:$cmd" in
        apt:python3) echo "python3" ;;
        apt:zip) echo "zip" ;;
        apt:unzip) echo "unzip" ;;
        apt:jq) echo "jq" ;;
        apt:xmllint) echo "libxml2-utils" ;;
        apt:rg) echo "ripgrep" ;;
        apt:convert) echo "imagemagick" ;;
        apt:gh) echo "gh" ;;

        dnf:python3|yum:python3) echo "python3" ;;
        dnf:zip|yum:zip) echo "zip" ;;
        dnf:unzip|yum:unzip) echo "unzip" ;;
        dnf:jq|yum:jq) echo "jq" ;;
        dnf:xmllint|yum:xmllint) echo "libxml2" ;;
        dnf:rg|yum:rg) echo "ripgrep" ;;
        dnf:convert|yum:convert) echo "ImageMagick" ;;
        dnf:gh|yum:gh) echo "gh" ;;

        pacman:python3) echo "python" ;;
        pacman:zip) echo "zip" ;;
        pacman:unzip) echo "unzip" ;;
        pacman:jq) echo "jq" ;;
        pacman:xmllint) echo "libxml2" ;;
        pacman:rg) echo "ripgrep" ;;
        pacman:convert) echo "imagemagick" ;;
        pacman:gh) echo "github-cli" ;;

        zypper:python3) echo "python3" ;;
        zypper:zip) echo "zip" ;;
        zypper:unzip) echo "unzip" ;;
        zypper:jq) echo "jq" ;;
        zypper:xmllint) echo "libxml2-tools" ;;
        zypper:rg) echo "ripgrep" ;;
        zypper:convert) echo "ImageMagick" ;;
        zypper:gh) echo "gh" ;;

        apk:python3) echo "python3" ;;
        apk:zip) echo "zip" ;;
        apk:unzip) echo "unzip" ;;
        apk:jq) echo "jq" ;;
        apk:xmllint) echo "libxml2-utils" ;;
        apk:rg) echo "ripgrep" ;;
        apk:convert) echo "imagemagick" ;;
        apk:gh) echo "github-cli" ;;

        brew:python3) echo "python@3" ;;
        brew:zip) echo "zip" ;;
        brew:unzip) echo "unzip" ;;
        brew:jq) echo "jq" ;;
        brew:xmllint) echo "libxml2" ;;
        brew:rg) echo "ripgrep" ;;
        brew:convert) echo "imagemagick" ;;
        brew:gh) echo "gh" ;;

        winget:python3) echo "Python.Python.3" ;;
        winget:zip) echo "" ;;
        winget:unzip) echo "" ;;
        winget:jq) echo "jqlang.jq" ;;
        winget:xmllint) echo "" ;;
        winget:rg) echo "BurntSushi.ripgrep.MSVC" ;;
        winget:convert) echo "ImageMagick.ImageMagick" ;;
        winget:gh) echo "GitHub.cli" ;;

        choco:python3) echo "python" ;;
        choco:zip) echo "zip" ;;
        choco:unzip) echo "unzip" ;;
        choco:jq) echo "jq" ;;
        choco:xmllint) echo "" ;;
        choco:rg) echo "ripgrep" ;;
        choco:convert) echo "imagemagick" ;;
        choco:gh) echo "gh" ;;
        *) echo "" ;;
    esac
}

install_pkg() {
    local manager="$1"
    local pkg="$2"
    [[ -z "$pkg" ]] && return 1

    case "$manager" in
        apt)
            if have_cmd sudo; then sudo apt-get update -y && sudo apt-get install -y "$pkg"; else apt-get update -y && apt-get install -y "$pkg"; fi
            ;;
        dnf)
            if have_cmd sudo; then sudo dnf install -y "$pkg"; else dnf install -y "$pkg"; fi
            ;;
        yum)
            if have_cmd sudo; then sudo yum install -y "$pkg"; else yum install -y "$pkg"; fi
            ;;
        pacman)
            if have_cmd sudo; then sudo pacman -Sy --noconfirm "$pkg"; else pacman -Sy --noconfirm "$pkg"; fi
            ;;
        zypper)
            if have_cmd sudo; then sudo zypper --non-interactive install "$pkg"; else zypper --non-interactive install "$pkg"; fi
            ;;
        apk)
            if have_cmd sudo; then sudo apk add --no-cache "$pkg"; else apk add --no-cache "$pkg"; fi
            ;;
        brew)
            brew install "$pkg"
            ;;
        winget)
            winget install --id "$pkg" --exact --silent
            ;;
        choco)
            choco install -y "$pkg"
            ;;
        *)
            return 1
            ;;
    esac
}

install_clasp() {
    if have_cmd clasp; then
        return 0
    fi
    if ! have_cmd npm; then
        return 1
    fi
    if have_cmd sudo; then
        sudo npm install -g @google/clasp
    else
        npm install -g @google/clasp
    fi
}

print_guidance() {
    local platform="$1"
    local manager="$2"
    local required_missing="$3"

    say ""
    say "Guia de preparacion del entorno:"

    case "$platform" in
        windows-bash)
            say "- Entorno detectado: Windows con Bash (Git Bash/MSYS/Cygwin)."
            say "- Recomendado para este kit: usar WSL (Ubuntu) o mantener Git Bash + winget/choco."
            ;;
        wsl)
            say "- Entorno detectado: WSL."
            say "- Recomendado: instalar dependencias con apt dentro de WSL."
            ;;
        macos)
            say "- Entorno detectado: macOS."
            say "- Recomendado: instalar Homebrew y luego dependencias del kit."
            ;;
        linux)
            say "- Entorno detectado: Linux."
            say "- Recomendado: usar el gestor de paquetes de la distro."
            ;;
        *)
            say "- Entorno no identificado con precision."
            say "- Recomendado: usar shell Bash + python3 + zip/unzip + xmllint + jq + rg."
            ;;
    esac

    case "$manager" in
        apt) say "- Instalacion sugerida: sudo apt-get update && sudo apt-get install -y python3 zip unzip jq libxml2-utils ripgrep" ;;
        dnf) say "- Instalacion sugerida: sudo dnf install -y python3 zip unzip jq libxml2 ripgrep ImageMagick" ;;
        yum) say "- Instalacion sugerida: sudo yum install -y python3 zip unzip jq libxml2 ripgrep ImageMagick" ;;
        pacman) say "- Instalacion sugerida: sudo pacman -Sy --noconfirm python zip unzip jq libxml2 ripgrep imagemagick" ;;
        zypper) say "- Instalacion sugerida: sudo zypper --non-interactive install python3 zip unzip jq libxml2-tools ripgrep ImageMagick" ;;
        apk) say "- Instalacion sugerida: sudo apk add --no-cache python3 zip unzip jq libxml2-utils ripgrep imagemagick" ;;
        brew) say "- Instalacion sugerida: brew install python@3 zip unzip jq libxml2 ripgrep imagemagick" ;;
        winget) say "- Instalacion sugerida (PowerShell): winget install --id Python.Python.3 --exact ; winget install --id jqlang.jq --exact ; winget install --id BurntSushi.ripgrep.MSVC --exact ; winget install --id ImageMagick.ImageMagick --exact" ;;
        choco) say "- Instalacion sugerida (PowerShell admin): choco install -y python jq ripgrep imagemagick zip unzip" ;;
        none)
            say "- No se detecto gestor compatible para auto-instalacion."
            if [[ "$platform" == "windows-bash" ]]; then
                say "- En Windows puro, opciones recomendadas:"
                say "  1) Instalar WSL (Ubuntu) y usar este kit dentro de WSL."
                say "  2) Usar Git Bash + winget/choco para dependencias base."
            fi
            ;;
    esac

    say "- Opcional para Google Apps Script: npm install -g @google/clasp"
    say "- Opcional para GitHub CLI: instalar 'gh' si vas a trabajar con GitHub."

    if [[ "$required_missing" -gt 0 ]]; then
        say "- Estado: faltan dependencias requeridas; la IA debe detener el flujo de edicion hasta resolverlas."
    else
        say "- Estado: entorno minimo operativo; puedes continuar."
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) MODE="install" ;;
        --yes) AUTO_YES=1 ;;
        --fail-on-missing) FAIL_ON_MISSING=1 ;;
        -h|--help) usage; exit 0 ;;
        *) say "Opcion no reconocida: $1"; usage; exit 2 ;;
    esac
    shift
done

PKG_MANAGER="$(detect_pkg_manager)"
PLATFORM="$(detect_runtime_platform)"
say "Sistema de paquetes detectado: ${PKG_MANAGER}"
say "Plataforma detectada: ${PLATFORM}"

REQUIRED_CMDS=("bash" "zip" "unzip" "python3")
RECOMMENDED_CMDS=("xmllint" "jq" "rg")
OPTIONAL_CMDS=("gh" "clasp" "convert")

missing_required=()
missing_recommended=()
missing_optional=()

for cmd in "${REQUIRED_CMDS[@]}"; do
    if have_cmd "$cmd"; then ok "Requerido disponible: $cmd"; else fail "Requerido faltante: $cmd"; missing_required+=("$cmd"); fi
done

for cmd in "${RECOMMENDED_CMDS[@]}"; do
    if have_cmd "$cmd"; then ok "Recomendado disponible: $cmd"; else warn "Recomendado faltante: $cmd"; missing_recommended+=("$cmd"); fi
done

for cmd in "${OPTIONAL_CMDS[@]}"; do
    if have_cmd "$cmd"; then ok "Opcional disponible: $cmd"; else warn "Opcional faltante: $cmd"; missing_optional+=("$cmd"); fi
done

attempt_install() {
    local cmd="$1"
    local pkg
    pkg="$(pkg_for_cmd "$PKG_MANAGER" "$cmd")"

    if [[ "$cmd" == "clasp" ]]; then
        if install_clasp; then
            ok "Instalado: clasp (npm @google/clasp)"
            return 0
        fi
        warn "No se pudo instalar clasp automaticamente (requiere npm)"
        return 1
    fi

    if [[ -z "$pkg" ]]; then
        warn "Sin mapeo de paquete para '$cmd' en gestor '$PKG_MANAGER'"
        return 1
    fi

    if install_pkg "$PKG_MANAGER" "$pkg"; then
        ok "Instalado: $cmd ($pkg)"
        return 0
    fi

    warn "Fallo instalando $cmd ($pkg)"
    return 1
}

if [[ "$MODE" == "install" ]]; then
    if [[ "$PKG_MANAGER" == "none" ]]; then
        warn "No hay gestor de paquetes compatible detectado para auto-instalacion"
    else
        if confirm "Intentar instalar dependencias faltantes ahora?"; then
            for cmd in "${missing_required[@]}" "${missing_recommended[@]}" "${missing_optional[@]}"; do
                [[ -z "$cmd" ]] && continue
                attempt_install "$cmd" || true
            done
        else
            warn "Instalacion omitida por usuario"
        fi
    fi
fi

say ""
say "Resumen final:"
missing_required_after=0
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! have_cmd "$cmd"; then
        missing_required_after=$((missing_required_after + 1))
        fail "Falta requerido: $cmd"
    fi
done

for cmd in "${RECOMMENDED_CMDS[@]}"; do
    if ! have_cmd "$cmd"; then
        warn "Falta recomendado: $cmd"
    fi
done

for cmd in "${OPTIONAL_CMDS[@]}"; do
    if ! have_cmd "$cmd"; then
        warn "Falta opcional: $cmd"
    fi
done

if [[ "$missing_required_after" -eq 0 ]]; then
    ok "Entorno minimo listo para trabajar con el kit"
else
    fail "Entorno incompleto: faltan ${missing_required_after} dependencia(s) requerida(s)"
fi

print_guidance "$PLATFORM" "$PKG_MANAGER" "$missing_required_after"

if [[ "$FAIL_ON_MISSING" -eq 1 && "$missing_required_after" -gt 0 ]]; then
    exit 1
fi

exit 0
