#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_EXE_REPO="/home/jjdeharo/Documentos/github/exelearning"
EXE_REPO_DIR="${EXE_REPO_DIR:-$DEFAULT_EXE_REPO}"
IDEVICE_BASE_DIR="${EXE_REPO_DIR}/public/files/perm/idevices/base"
OUT_MD="${REPO_DIR}/catalogo_idevices.md"
OUT_JSON="${REPO_DIR}/catalogo_idevices.json"

usage() {
    cat <<'EOF'
Uso:
  generate-idevice-catalog.sh

Genera:
  - catalogo_idevices.md
  - catalogo_idevices.json

La informacion se extrae del clon local de eXe.
EOF
}

check_repo() {
    if [[ ! -d "${IDEVICE_BASE_DIR}" ]]; then
        echo "No se encuentra el repo de eXe en: ${EXE_REPO_DIR}" >&2
        echo "Puedes sobrescribirlo exportando EXE_REPO_DIR=/ruta/al/repo" >&2
        exit 2
    fi
}

xml_tag_value() {
    local file="$1"
    local tag="$2"
    local value
    value="$(grep -o "<${tag}>[^<]*</${tag}>" "$file" | head -n 1 | sed "s#<${tag}>##; s#</${tag}>##")" || true
    printf '%s' "$value"
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

main() {
    check_repo

    local dirs=()
    mapfile -t dirs < <(find "${IDEVICE_BASE_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

    {
        printf '# Catalogo de iDevices disponibles\n\n'
        printf 'Este catalogo se ha generado automaticamente a partir del clon local de eXe.\n\n'
        printf '## Resumen\n\n'
        printf -- '- Total de iDevices detectados: %s\n' "${#dirs[@]}"
        printf -- '- Ruta base analizada: `%s`\n\n' "${IDEVICE_BASE_DIR}"
        printf '## Tabla\n\n'
        printf '| Tipo | Titulo | Categoria | Export | Config |\n'
        printf '| :--- | :--- | :--- | :---: | :---: |\n'
    } > "${OUT_MD}"

    printf '[\n' > "${OUT_JSON}"

    local first=1
    local dir
    for dir in "${dirs[@]}"; do
        local config_file="${IDEVICE_BASE_DIR}/${dir}/config.xml"
        local export_dir="${IDEVICE_BASE_DIR}/${dir}/export"
        local title=""
        local category=""
        local has_config="no"
        local has_export="no"

        if [[ -f "${config_file}" ]]; then
            has_config="yes"
            title="$(xml_tag_value "${config_file}" title)"
            category="$(xml_tag_value "${config_file}" category)"
        fi

        if [[ -d "${export_dir}" ]]; then
            has_export="yes"
        fi

        if [[ -z "${title}" ]]; then
            title="${dir}"
        fi

        if [[ -z "${category}" ]]; then
            category="-"
        fi

        printf '| `%s` | %s | %s | %s | %s |\n' \
            "${dir}" "${title}" "${category}" "${has_export}" "${has_config}" >> "${OUT_MD}"

        if [[ "${first}" -eq 0 ]]; then
            printf ',\n' >> "${OUT_JSON}"
        fi
        first=0

        printf '  {"type":"%s","title":"%s","category":"%s","has_export":%s,"has_config":%s}' \
            "$(json_escape "${dir}")" \
            "$(json_escape "${title}")" \
            "$(json_escape "${category}")" \
            "$([[ "${has_export}" = "yes" ]] && printf 'true' || printf 'false')" \
            "$([[ "${has_config}" = "yes" ]] && printf 'true' || printf 'false')" >> "${OUT_JSON}"
    done

    printf '\n]\n' >> "${OUT_JSON}"

    printf 'Catalogo generado en:\n- %s\n- %s\n' "${OUT_MD}" "${OUT_JSON}"
}

if [[ "${1:-}" = "-h" || "${1:-}" = "--help" || "${1:-}" = "help" ]]; then
    usage
    exit 0
fi

main
