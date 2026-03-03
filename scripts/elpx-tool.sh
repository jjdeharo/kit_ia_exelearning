#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_DIR="${REPO_DIR}/plantillas/plantilla_base_minima"
THEME_TEMPLATE_PREFIX="${REPO_DIR}/plantillas/tema_"

usage() {
    cat <<'EOF'
Uso:
  elpx-tool.sh create [--theme TEMA] <directorio_destino> [titulo] [archivo_salida.elpx]
  elpx-tool.sh pack <directorio_proyecto> <archivo_salida.elpx>
  elpx-tool.sh unpack <archivo_entrada.elpx> <directorio_destino>
  elpx-tool.sh list-themes

Comandos:
  create  Crea un proyecto nuevo a partir de la plantilla base.
          Si se indica archivo_salida.elpx, tambien lo empaqueta.
  pack    Empaqueta un directorio de proyecto como .elpx.
  unpack  Descomprime un .elpx en un directorio para editarlo.
  list-themes  Muestra los temas con plantilla disponibles.
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

extract_ode_property_value() {
    local file="$1"
    local property_key="$2"
    awk -v wanted="$property_key" '
        /<odeProperty>/ { in_prop=1; key="" }
        in_prop && $0 ~ "<key>" wanted "</key>" { key=wanted }
        in_prop && key == wanted && $0 ~ /<value>/ {
            line=$0
            sub(/^.*<value>/, "", line)
            sub(/<\/value>.*$/, "", line)
            print line
            exit
        }
        /<\/odeProperty>/ { in_prop=0; key="" }
    ' "$file"
}

extract_ode_resource_value() {
    local file="$1"
    local resource_key="$2"
    awk -v wanted="$resource_key" '
        /<odeResource>/ { in_res=1; key="" }
        in_res && $0 ~ "<key>" wanted "</key>" { key=wanted }
        in_res && key == wanted && $0 ~ /<value>/ {
            line=$0
            sub(/^.*<value>/, "", line)
            sub(/<\/value>.*$/, "", line)
            print line
            exit
        }
        /<\/odeResource>/ { in_res=0; key="" }
    ' "$file"
}

extract_first_page_title() {
    local file="$1"
    awk '
        /<odeNavStructure>/ { in_nav=1 }
        in_nav && /<pageName>/ {
            line=$0
            sub(/^.*<pageName>/, "", line)
            sub(/<\/pageName>.*$/, "", line)
            print line
            exit
        }
        /<\/odeNavStructure>/ { in_nav=0 }
    ' "$file"
}

extract_first_page_id() {
    local file="$1"
    awk '
        /<odeNavStructure>/ { in_nav=1 }
        in_nav && /<odePageId>/ {
            line=$0
            sub(/^.*<odePageId>/, "", line)
            sub(/<\/odePageId>.*$/, "", line)
            print line
            exit
        }
        /<\/odeNavStructure>/ { in_nav=0 }
    ' "$file"
}

resolve_template_dir() {
    local theme="${1:-base}"
    case "$theme" in
        base)
            printf '%s\n' "${TEMPLATE_DIR}"
            ;;
        *)
            printf '%s\n' "${THEME_TEMPLATE_PREFIX}${theme}"
            ;;
    esac
}

list_themes() {
    printf '%s\n' "base"
    find "${REPO_DIR}/plantillas" -maxdepth 1 -type d -name 'tema_*' -printf '%f\n' \
        | sed 's/^tema_//' \
        | sort
}

customize_real_theme_template() {
    local target_dir="$1"
    local title="$2"
    local page_title="$3"
    local page_id="$4"
    local ode_id="$5"
    local ode_version_id="$6"
    local content_file="${target_dir}/content.xml"
    local index_file="${target_dir}/index.html"
    local current_title
    local current_page_title
    local current_page_id
    local current_ode_id
    local current_ode_version_id

    current_title="$(extract_ode_property_value "${content_file}" "pp_title")"
    current_page_title="$(extract_first_page_title "${content_file}")"
    current_page_id="$(extract_first_page_id "${content_file}")"
    current_ode_id="$(extract_ode_resource_value "${content_file}" "odeId")"
    current_ode_version_id="$(extract_ode_resource_value "${content_file}" "odeVersionId")"

    [[ -n "${current_title}" ]] || current_title="Untitled"
    [[ -n "${current_page_title}" ]] || current_page_title="New page"
    [[ -n "${current_page_id}" ]] || return 1
    [[ -n "${current_ode_id}" ]] || return 1
    [[ -n "${current_ode_version_id}" ]] || return 1

    replace_placeholder "${content_file}" "${current_title}" "${title}"
    replace_placeholder "${content_file}" "${current_page_title}" "${page_title}"
    replace_placeholder "${content_file}" "${current_page_id}" "${page_id}"
    replace_placeholder "${content_file}" "${current_ode_id}" "${ode_id}"
    replace_placeholder "${content_file}" "${current_ode_version_id}" "${ode_version_id}"

    replace_placeholder "${index_file}" "${current_title}" "${title}"
    replace_placeholder "${index_file}" "${current_page_title}" "${page_title}"
    replace_placeholder "${index_file}" "${current_page_id}" "${page_id}"
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
    local theme="${4:-base}"
    local target_abs
    local page_title="Inicio"
    local ode_id
    local ode_version_id
    local page_id
    local block_id
    local idevice_id
    local selected_template_dir

    selected_template_dir="$(resolve_template_dir "${theme}")"

    if [[ ! -d "${selected_template_dir}" ]]; then
        echo "No se encuentra la plantilla para el tema '${theme}' en ${selected_template_dir}" >&2
        exit 1
    fi

    target_abs="$(abs_path "$target_dir")"
    if [[ -e "${target_abs}" ]]; then
        echo "El destino ya existe: ${target_abs}" >&2
        exit 1
    fi

    mkdir -p "$(dirname "${target_abs}")"
    cp -a "${selected_template_dir}" "${target_abs}"
    rm -f "${target_abs}/.elpx-template"

    ode_id="$(generate_id "AUTOIA")"
    ode_version_id="$(generate_id "REV001")"
    page_id="$(generate_id "PAGE01")"
    block_id="$(generate_id "BLK001")"
    idevice_id="$(generate_id "IDEV01")"

    if grep -q "__PROJECT_TITLE__" "${target_abs}/content.xml"; then
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
    else
        if ! customize_real_theme_template "${target_abs}" "${title}" "${page_title}" "${page_id}" "${ode_id}" "${ode_version_id}"; then
            echo "No se ha podido ajustar la plantilla del tema '${theme}'" >&2
            exit 1
        fi
    fi

    echo "Proyecto creado en: ${target_abs} (tema: ${theme})"

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
            local theme="base"
            shift
            if [[ "${1:-}" = "--theme" ]]; then
                [[ $# -ge 3 ]] || { usage; exit 1; }
                theme="${2}"
                shift 2
            fi
            if [[ $# -lt 1 || $# -gt 3 ]]; then
                usage
                exit 1
            fi
            create_project "${1}" "${2:-}" "${3:-}" "${theme}"
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
        list-themes)
            if [[ $# -ne 1 ]]; then
                usage
                exit 1
            fi
            list_themes
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
