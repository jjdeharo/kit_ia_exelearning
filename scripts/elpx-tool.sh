#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_DIR="${REPO_DIR}/plantillas/plantilla_base_minima"

usage() {
    cat <<'EOF'
Uso:
  elpx-tool.sh create <directorio_destino> [titulo] [archivo_salida.elpx]
  elpx-tool.sh pack <directorio_proyecto> <archivo_salida.elpx>
  elpx-tool.sh unpack <archivo_entrada.elpx> <directorio_destino>

Comandos:
  create  Crea un proyecto nuevo a partir de la plantilla base.
          Si se indica archivo_salida.elpx, tambien lo empaqueta.
  pack    Empaqueta un directorio de proyecto como .elpx.
  unpack  Descomprime un .elpx en un directorio para editarlo.
EOF
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Falta el comando requerido: $1" >&2
        exit 1
    fi
}

abs_path() {
    local target="$1"
    if [[ "$target" = /* ]]; then
        printf '%s\n' "$target"
    else
        printf '%s\n' "$(pwd)/$target"
    fi
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

generate_id() {
    local suffix="$1"
    printf '%s%s\n' "$(date +%Y%m%d%H%M%S)" "$suffix"
}

replace_placeholder() {
    local file="$1"
    local placeholder="$2"
    local value="$3"
    local escaped
    escaped="$(escape_sed_replacement "$value")"
    sed -i "s/${placeholder}/${escaped}/g" "$file"
}

normalize_export_html_paths() {
    local project_dir="$1"
    local index_html
    local page_html

    index_html="${project_dir}/index.html"
    if [[ -f "${index_html}" ]]; then
        sed -i \
            -e 's#{{context_path}}/content/resources/#content/resources/#g' \
            -e 's#{{context_path}}/#content/resources/#g' \
            "${index_html}"
    fi

    if [[ -d "${project_dir}/html" ]]; then
        while IFS= read -r page_html; do
            sed -i \
                -e 's#{{context_path}}/content/resources/#../content/resources/#g' \
                -e 's#{{context_path}}/#../content/resources/#g' \
                "${page_html}"
        done < <(find "${project_dir}/html" -maxdepth 1 -type f -name '*.html' | sort)
    fi
}

create_project() {
    local target_dir="$1"
    local title="${2:-Mi proyecto eXeLearning}"
    local output_elpx="${3:-}"
    local target_abs
    local page_title="Inicio"
    local ode_id
    local ode_version_id
    local page_id
    local block_id
    local idevice_id

    if [[ ! -d "${TEMPLATE_DIR}" ]]; then
        echo "No se encuentra la plantilla base en ${TEMPLATE_DIR}" >&2
        exit 1
    fi

    target_abs="$(abs_path "$target_dir")"
    if [[ -e "${target_abs}" ]]; then
        echo "El destino ya existe: ${target_abs}" >&2
        exit 1
    fi

    mkdir -p "$(dirname "${target_abs}")"
    cp -a "${TEMPLATE_DIR}" "${target_abs}"
    rm -f "${target_abs}/.elpx-template"

    ode_id="$(generate_id "AUTOIA")"
    ode_version_id="$(generate_id "REV001")"
    page_id="$(generate_id "PAGE01")"
    block_id="$(generate_id "BLK001")"
    idevice_id="$(generate_id "IDEV01")"

    replace_placeholder "${target_abs}/content.xml" "__PROJECT_TITLE__" "$title"
    replace_placeholder "${target_abs}/content.xml" "__PAGE_TITLE__" "$page_title"
    replace_placeholder "${target_abs}/content.xml" "__ODE_ID__" "$ode_id"
    replace_placeholder "${target_abs}/content.xml" "__ODE_VERSION_ID__" "$ode_version_id"
    replace_placeholder "${target_abs}/content.xml" "__PAGE_ID__" "$page_id"
    replace_placeholder "${target_abs}/content.xml" "__BLOCK_ID__" "$block_id"
    replace_placeholder "${target_abs}/content.xml" "__IDEVICE_ID__" "$idevice_id"

    replace_placeholder "${target_abs}/index.html" "__PROJECT_TITLE__" "$title"
    replace_placeholder "${target_abs}/index.html" "__PAGE_TITLE__" "$page_title"
    replace_placeholder "${target_abs}/index.html" "__PAGE_ID__" "$page_id"
    replace_placeholder "${target_abs}/index.html" "__BLOCK_ID__" "$block_id"
    replace_placeholder "${target_abs}/index.html" "__IDEVICE_ID__" "$idevice_id"

    echo "Proyecto creado en: ${target_abs}"

    if [[ -n "${output_elpx}" ]]; then
        pack_project "${target_abs}" "${output_elpx}"
    fi
}

pack_project() {
    local source_dir="$1"
    local output_file="$2"
    local source_abs
    local output_abs

    require_cmd zip

    source_abs="$(abs_path "$source_dir")"
    output_abs="$(abs_path "$output_file")"

    if [[ ! -d "${source_abs}" ]]; then
        echo "No existe el directorio de proyecto: ${source_abs}" >&2
        exit 1
    fi

    # Make exported HTML behave like native eXe export:
    # - keep {{context_path}} in content.xml for editor compatibility
    # - resolve it in HTML files to content/resources relative paths
    normalize_export_html_paths "${source_abs}"

    mkdir -p "$(dirname "${output_abs}")"

    (
        cd "${source_abs}"
        zip -rq -FS "${output_abs}" . \
            -x 'README.md' \
            -x '.elpx-template' \
            -x '*.elpx' \
            -x '__MACOSX/*' \
            -x '.DS_Store'
    )

    echo "Paquete generado en: ${output_abs}"
}

unpack_project() {
    local input_file="$1"
    local target_dir="$2"
    local input_abs
    local target_abs

    require_cmd unzip

    input_abs="$(abs_path "$input_file")"
    target_abs="$(abs_path "$target_dir")"

    if [[ ! -f "${input_abs}" ]]; then
        echo "No existe el archivo .elpx: ${input_abs}" >&2
        exit 1
    fi

    if [[ -e "${target_abs}" ]]; then
        echo "El destino ya existe: ${target_abs}" >&2
        exit 1
    fi

    mkdir -p "${target_abs}"
    unzip -q "${input_abs}" -d "${target_abs}"
    echo "Paquete descomprimido en: ${target_abs}"
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    case "$1" in
        create)
            if [[ $# -lt 2 || $# -gt 4 ]]; then
                usage
                exit 1
            fi
            create_project "${2}" "${3:-}" "${4:-}"
            ;;
        pack)
            if [[ $# -ne 3 ]]; then
                usage
                exit 1
            fi
            pack_project "${2}" "${3}"
            ;;
        unpack)
            if [[ $# -ne 3 ]]; then
                usage
                exit 1
            fi
            unpack_project "${2}" "${3}"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
