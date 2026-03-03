#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Uso:
  validate-elpx.sh <archivo.elpx|directorio_descomprimido>

Valida un paquete .elpx o un directorio ya descomprimido y comprueba:
  - estructura minima
  - referencias locales en HTML
  - estructura HTML base compatible con eXe
  - presencia basica de content.xml
  - carpetas de idevices usadas
  - estructura didactica minima (no proyecto de un unico iDevice)
  - sincronizacion entre htmlView y jsonProperties en iDevices text
  - ausencia de placeholders sin sustituir
  - valores de ejemplo sospechosos que conviene revisar
EOF
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Falta el comando requerido: $1" >&2
        exit 2
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

FAILURES=0
WARNINGS=0
IS_TEMPLATE_SOURCE=0

ok() {
    printf '[OK] %s\n' "$1"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    printf '[WARN] %s\n' "$1"
}

fail() {
    FAILURES=$((FAILURES + 1))
    printf '[FAIL] %s\n' "$1"
}

check_exists() {
    local root="$1"
    local path="$2"
    if [[ -e "${root}/${path}" ]]; then
        ok "Existe ${path}"
    else
        fail "Falta ${path}"
    fi
}

is_local_ref() {
    local ref="$1"
    [[ -z "$ref" ]] && return 1
    [[ "$ref" =~ ^https?:// ]] && return 1
    [[ "$ref" =~ ^mailto: ]] && return 1
    [[ "$ref" =~ ^tel: ]] && return 1
    [[ "$ref" =~ ^data: ]] && return 1
    [[ "$ref" =~ ^javascript: ]] && return 1
    [[ "$ref" =~ ^# ]] && return 1
    return 0
}

resolve_ref() {
    local base_dir="$1"
    local ref="$2"
    local candidate

    ref="${ref%%\?*}"
    ref="${ref%%#*}"

    # eXe usa {{context_path}} en algunos iDevices (p.ej. textTextarea) para referenciar
    # recursos del proyecto en content/resources/. En export HTML el runtime lo resuelve
    # al prefijo correcto segun la profundidad; aqui validamos contra el arbol del .elpx.
    local ctx_prefix='{{context_path}}/'
    if [[ "$ref" == "${ctx_prefix}"* ]]; then
        ref="content/resources/${ref#${ctx_prefix}}"
        candidate="${ROOT_DIR}/${ref}"
        [[ -e "$candidate" ]] && return 0
        return 1
    fi

    if [[ "$ref" = /* ]]; then
        candidate="$ROOT_DIR${ref}"
    else
        candidate="${base_dir}/${ref}"
    fi

    if [[ -e "$candidate" ]]; then
        return 0
    fi

    return 1
}

normalize_markup_to_text() {
    sed -E 's/<[^>]+>/ /g' \
        | sed -e 's/&nbsp;/ /g' \
              -e 's/&amp;/\&/g' \
              -e 's/&lt;/</g' \
              -e 's/&gt;/>/g' \
              -e 's/&quot;/"/g' \
              -e "s/&#39;/'/g" \
        | tr '\n\r\t' '   ' \
        | tr -s ' ' \
        | sed -e 's/^ //' -e 's/ $//'
}

validate_xml_basic() {
    local xml="$1"

    if command -v xmllint >/dev/null 2>&1; then
        if xmllint --noout "$xml" >/dev/null 2>&1; then
            ok "content.xml es XML bien formado"
        else
            fail "content.xml no es XML bien formado"
        fi
    else
        warn "xmllint no esta disponible; se realiza solo validacion basica"
    fi

    grep -q '<ode' "$xml" && ok "content.xml contiene <ode>" || fail "content.xml no contiene <ode>"
    grep -q '<odeNavStructures' "$xml" && ok "content.xml contiene <odeNavStructures>" || fail "content.xml no contiene <odeNavStructures>"
    grep -q '<odeComponent' "$xml" && ok "content.xml contiene componentes" || fail "content.xml no contiene <odeComponent>"
    grep -q '<htmlView' "$xml" && ok "content.xml contiene htmlView" || fail "content.xml no contiene htmlView"
    grep -q '<jsonProperties' "$xml" && ok "content.xml contiene jsonProperties" || fail "content.xml no contiene jsonProperties"

    local types_file
    types_file="$(mktemp)"
    grep -o '<odeIdeviceTypeName>[^<]*</odeIdeviceTypeName>' "$xml" \
        | sed 's#<odeIdeviceTypeName>##; s#</odeIdeviceTypeName>##' \
        | sort -u > "$types_file" || true

    if [[ ! -s "$types_file" ]]; then
        warn "No se han encontrado odeIdeviceTypeName en content.xml"
    else
        while IFS= read -r idevice_type; do
            [[ -z "$idevice_type" ]] && continue
            if [[ -d "${ROOT_DIR}/idevices/${idevice_type}" ]]; then
                ok "Existe idevices/${idevice_type}"
            else
                fail "Falta la carpeta idevices/${idevice_type} usada en content.xml"
            fi
        done < "$types_file"
    fi

    rm -f "$types_file"
}

validate_text_idevice_sync() {
    local xml="$1"
    local count_raw
    local count
    local i
        local html_view
        local json_props
        local textarea_html
        local html_norm
        local textarea_norm
        local html_len
        local textarea_len
    local html_img_file
    local textarea_img_file
    local missing_img_file
    local decoded_textarea_html
    local text_img_count
    local html_has_rich
    local textarea_has_html

    if ! command -v xmllint >/dev/null 2>&1; then
        warn "No se valida sincronizacion htmlView/jsonProperties en iDevice text (falta xmllint)"
        return
    fi

    if ! command -v jq >/dev/null 2>&1; then
        warn "No se valida sincronizacion htmlView/jsonProperties en iDevice text (falta jq)"
        return
    fi

    count_raw="$(xmllint --xpath 'count(//*[local-name()="odeComponent"][*[local-name()="odeIdeviceTypeName" and normalize-space(text())="text"]])' "$xml" 2>/dev/null || echo "0")"
    count="${count_raw%%.*}"
    [[ -z "$count" ]] && count=0

    if [[ "$count" -eq 0 ]]; then
        ok "No hay iDevices text para validar sincronizacion"
        return
    fi

    for ((i = 1; i <= count; i++)); do
        html_view="$(xmllint --xpath "string((//*[local-name()='odeComponent'][*[local-name()='odeIdeviceTypeName' and normalize-space(text())='text']])[$i]/*[local-name()='htmlView'])" "$xml" 2>/dev/null || true)"
        json_props="$(xmllint --xpath "string((//*[local-name()='odeComponent'][*[local-name()='odeIdeviceTypeName' and normalize-space(text())='text']])[$i]/*[local-name()='jsonProperties'])" "$xml" 2>/dev/null || true)"

        if [[ -z "$json_props" ]]; then
            fail "iDevice text #${i} sin jsonProperties"
            continue
        fi

        textarea_html="$(printf '%s' "$json_props" | jq -er '.textTextarea // empty' 2>/dev/null || true)"
        if [[ -z "$textarea_html" ]]; then
            fail "iDevice text #${i} sin textTextarea en jsonProperties"
            continue
        fi

        html_has_rich=0
        if printf '%s' "$html_view" | grep -Eiq '<(h[1-6]|p|ul|ol|li|img|table|blockquote|div|figure)\b'; then
            html_has_rich=1
        fi
        textarea_has_html=0
        if printf '%s' "$textarea_html" | grep -Eiq '(<[a-z][a-z0-9]*(\s|>)|&lt;[a-z][a-z0-9]*(&gt;|\s))'; then
            textarea_has_html=1
        fi
        if [[ "$html_has_rich" -eq 1 && "$textarea_has_html" -eq 0 ]]; then
            fail "iDevice text #${i} sin formato HTML en textTextarea: el editor mostrara texto plano"
            continue
        fi

        html_img_file="$(mktemp)"
        textarea_img_file="$(mktemp)"
        missing_img_file="$(mktemp)"

        printf '%s' "$html_view" \
            | grep -Eoi '<img[^>]*src="[^"]+"' \
            | sed -E 's#.*src="([^"]+)".*#\1#' \
            | sort -u > "$html_img_file" || true

        printf '%s' "$textarea_html" \
            | grep -Eoi '(<img[^>]*src="[^"]+"|&lt;img[^&]*src=&quot;[^&]+&quot;)' \
            | sed -E 's#.*src="([^"]+)".*#\1#; s#.*src=&quot;([^&]+)&quot;.*#\1#' \
            | sort -u > "$textarea_img_file" || true

        if [[ -s "$html_img_file" ]]; then
            comm -23 "$html_img_file" "$textarea_img_file" > "$missing_img_file" || true
            if [[ -s "$missing_img_file" ]]; then
                fail "iDevice text #${i} desincronizado en imagenes: faltan src en textTextarea ($(paste -sd ', ' "$missing_img_file"))"
                rm -f "$html_img_file" "$textarea_img_file" "$missing_img_file"
                continue
            fi
        fi

        if grep -Eq '^content/resources/' "$textarea_img_file"; then
            fail "iDevice text #${i} usa rutas content/resources en textTextarea: para el editor usar {{context_path}}/<carpeta>/<archivo>"
            rm -f "$html_img_file" "$textarea_img_file" "$missing_img_file"
            continue
        fi

        if grep -Eiq '\.svg($|[?#])' "$textarea_img_file"; then
            fail "iDevice text #${i} usa SVG en textTextarea: para compatibilidad de editor usar PNG/JPG/WebP"
            rm -f "$html_img_file" "$textarea_img_file" "$missing_img_file"
            continue
        fi

        rm -f "$html_img_file" "$textarea_img_file" "$missing_img_file"

        decoded_textarea_html="$(printf '%s' "$textarea_html" \
            | sed -e 's/&lt;/</g' \
                  -e 's/&gt;/>/g' \
                  -e 's/&quot;/"/g' \
                  -e "s/&#39;/'/g" \
                  -e 's/&amp;/\&/g')"
        text_img_count="$(printf '%s' "$decoded_textarea_html" | grep -Eoi '<img\b' | wc -l | tr -d ' ' || true)"

        if [[ "${text_img_count}" -gt 0 ]]; then
            if ! printf '%s' "$decoded_textarea_html" | grep -Eiq '<figcaption[^>]*class="[^"]*figcaption[^"]*"'; then
                fail "iDevice text #${i} con imagenes sin figcaption de eXe"
                continue
            fi
            if ! printf '%s' "$decoded_textarea_html" | grep -Eiq 'class="[^"]*author[^"]*"'; then
                fail "iDevice text #${i} con imagenes sin campo author en figcaption"
                continue
            fi
            if ! printf '%s' "$decoded_textarea_html" | grep -Eiq '<a[^>]*(class="[^"]*title[^"]*"[^>]*href="https?://[^"]+"|href="https?://[^"]+"[^>]*class="[^"]*title[^"]*")'; then
                fail "iDevice text #${i} con imagenes sin URL de origen en class title"
                continue
            fi
            if ! printf '%s' "$decoded_textarea_html" | grep -Eiq 'class="[^"]*license[^"]*"'; then
                fail "iDevice text #${i} con imagenes sin bloque license en figcaption"
                continue
            fi
            if ! printf '%s' "$decoded_textarea_html" | grep -Eiq 'rel="license'; then
                fail "iDevice text #${i} con imagenes sin enlace de licencia (rel=\"license\")"
                continue
            fi
        fi

        html_norm="$(printf '%s' "$html_view" | normalize_markup_to_text)"
        textarea_norm="$(printf '%s' "$textarea_html" | normalize_markup_to_text)"
        html_len="${#html_norm}"
        textarea_len="${#textarea_norm}"

        if [[ "$html_norm" != "$textarea_norm" ]]; then
            fail "iDevice text #${i} desincronizado: htmlView y jsonProperties.textTextarea no coinciden (len html=${html_len}, len json=${textarea_len})"
        else
            ok "iDevice text #${i} sincronizado entre htmlView y jsonProperties"
        fi
    done
}

validate_didactic_minimum_structure() {
    local xml="$1"
    local pages_raw
    local pages
    local components_raw
    local components
    local i
    local blocks_raw
    local blocks

    if ! command -v xmllint >/dev/null 2>&1; then
        warn "No se valida estructura didactica minima (falta xmllint)"
        return
    fi

    pages_raw="$(xmllint --xpath 'count(//*[local-name()="odeNavStructure"])' "$xml" 2>/dev/null || echo "0")"
    pages="${pages_raw%%.*}"
    [[ -z "$pages" ]] && pages=0

    components_raw="$(xmllint --xpath 'count(//*[local-name()="odeComponent"])' "$xml" 2>/dev/null || echo "0")"
    components="${components_raw%%.*}"
    [[ -z "$components" ]] && components=0

    if [[ "$pages" -lt 1 ]]; then
        fail "No se han detectado paginas (odeNavStructure)"
        return
    fi

    if [[ "$components" -lt 1 ]]; then
        fail "No se han detectado iDevices (odeComponent)"
        return
    fi

    for ((i = 1; i <= pages; i++)); do
        blocks_raw="$(xmllint --xpath "count((//*[local-name()='odeNavStructure'])[$i]/*[local-name()='odePagStructures']/*[local-name()='odePagStructure'])" "$xml" 2>/dev/null || echo "0")"
        blocks="${blocks_raw%%.*}"
        [[ -z "$blocks" ]] && blocks=0
        if [[ "$blocks" -lt 1 ]]; then
            fail "Pagina #${i} sin bloques (odePagStructure)"
        fi
    done

    if [[ "$IS_TEMPLATE_SOURCE" -eq 1 ]]; then
        warn "Validacion didactica estricta omitida en plantilla fuente (.elpx-template)"
        return
    fi

    if [[ "$components" -lt 2 ]]; then
        fail "Proyecto con un unico iDevice: se requieren al menos 2 odeComponent para uso docente"
    else
        ok "Estructura didactica minima: ${pages} pagina(s), ${components} iDevice(s)"
    fi

    if [[ "$pages" -lt 2 ]]; then
        warn "Proyecto de una sola pagina: valido tecnicamente, pero se recomienda estructura multipagina para materiales amplios"
    else
        ok "Proyecto con varias paginas"
    fi

}

validate_unresolved_placeholders() {
    local root="$1"
    local scan_file
    local hits_file

    hits_file="$(mktemp)"

    while IFS= read -r scan_file; do
        [[ -f "$scan_file" ]] || continue
        grep -Eo '__[A-Z][A-Z0-9_]*__' "$scan_file" \
            | sed "s#^#${scan_file#${root}/}: #" >> "$hits_file" || true
    done < <(find "$root" -type f \( -name '*.xml' -o -name '*.html' -o -name '*.xhtml' -o -name '*.json' \) | sort)

    if [[ -s "$hits_file" ]]; then
        while IFS= read -r hit; do
            if [[ "$IS_TEMPLATE_SOURCE" -eq 1 ]]; then
                warn "Placeholder sin sustituir detectado en plantilla fuente: $hit"
            else
                fail "Placeholder sin sustituir detectado: $hit"
            fi
        done < "$hits_file"
    else
        ok "No quedan placeholders sin sustituir"
    fi

    rm -f "$hits_file"
}

validate_suspicious_example_content() {
    local root="$1"
    local hits_file
    local scan_file

    hits_file="$(mktemp)"

    while IFS= read -r scan_file; do
        [[ -f "$scan_file" ]] || continue

        grep -En \
            'https://example\.org|recurso\.ggb|imagen-1\.jpg|imagen-detalle\.jpg|mapa-base\.png|video\.mp4|Contenido de ejemplo|Texto complementario opcional|Descripcion breve del caso de estudio|Sitio web externo|Autor del recurso|>\\.\\.\\.<|\"\\.\\.\\.\"' \
            "$scan_file" \
            | sed "s#^#${scan_file#${root}/}: #" >> "$hits_file" || true
    done < <(find "$root" -type f \( -name '*.xml' -o -name '*.html' -o -name '*.xhtml' -o -name '*.json' \) | sort)

    if [[ -s "$hits_file" ]]; then
        while IFS= read -r hit; do
            warn "Contenido de ejemplo o referencia sospechosa: $hit"
        done < "$hits_file"
    else
        ok "No se han detectado valores de ejemplo evidentes"
    fi

    rm -f "$hits_file"
}

validate_html_refs() {
    local html_file="$1"
    local html_dir
    local refs_file

    html_dir="$(dirname "$html_file")"
    refs_file="$(mktemp)"

    grep -Eoi '(src|href)="[^"]+"' "$html_file" \
        | sed -E 's/^[^=]+="(.*)"$/\1/' > "$refs_file" || true

    while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        if ! is_local_ref "$ref"; then
            continue
        fi
        if [[ "$ref" == "{{context_path}}/"* ]]; then
            fail "Referencia con placeholder sin resolver en $(basename "$html_file"): $ref"
            continue
        fi
        if resolve_ref "$html_dir" "$ref"; then
            ok "Referencia local valida en $(basename "$html_file"): $ref"
        else
            fail "Referencia rota en $(basename "$html_file"): $ref"
        fi
    done < "$refs_file"

    rm -f "$refs_file"
}

validate_html_structure() {
    local html_file="$1"
    local page_name
    local article_count
    local idevice_count
    local nav_line
    local main_line

    page_name="$(basename "$html_file")"

    if ! grep -Eiq '<div[^>]*class="[^"]*exe-content[^"]*"' "$html_file"; then
        fail "Estructura eXe incompleta en ${page_name}: falta contenedor .exe-content"
    fi

    if ! grep -Eiq '<main[^>]*class="[^"]*page[^"]*"' "$html_file"; then
        fail "Estructura eXe incompleta en ${page_name}: falta <main class=\"page\">"
    fi

    if ! grep -Eiq '<div[^>]*class="[^"]*page-content[^"]*"' "$html_file"; then
        fail "Estructura eXe incompleta en ${page_name}: falta contenedor .page-content"
    fi

    if grep -Eiq '<header[^>]*id="header"[^>]*class="[^"]*main-header[^"]*"' "$html_file"; then
        fail "Estructura eXe no compatible en ${page_name}: se detecta <header id=\"header\" class=\"main-header\"> global antes del contenido"
    fi

    nav_line="$(grep -Enim1 '<nav[^>]*id="siteNav"' "$html_file" | cut -d: -f1 || true)"
    main_line="$(grep -Enim1 '<main\b' "$html_file" | cut -d: -f1 || true)"
    if [[ -n "$nav_line" && -n "$main_line" && "$nav_line" -gt "$main_line" ]]; then
        fail "Estructura eXe no compatible en ${page_name}: <nav id=\"siteNav\"> debe ir antes de <main>"
    fi

    article_count="$(grep -Eoi '<article\b[^>]*class="[^"]*box[^"]*"' "$html_file" | wc -l | tr -d ' ' || true)"
    [[ -z "$article_count" ]] && article_count=0
    if [[ "$article_count" -lt 1 ]]; then
        fail "Estructura eXe incompleta en ${page_name}: no hay <article class=\"box\">"
    fi

    if ! grep -Eiq '<div[^>]*class="[^"]*box-content[^"]*"' "$html_file"; then
        fail "Estructura eXe incompleta en ${page_name}: falta .box-content"
    fi

    idevice_count="$(grep -Eoi 'class="[^"]*idevice_node[^"]*"' "$html_file" | wc -l | tr -d ' ' || true)"
    [[ -z "$idevice_count" ]] && idevice_count=0
    if [[ "$idevice_count" -lt 1 ]]; then
        fail "Estructura eXe incompleta en ${page_name}: no hay nodos .idevice_node"
    fi

    if [[ "$article_count" -ge 1 && "$idevice_count" -ge 1 ]]; then
        ok "Estructura HTML eXe valida en ${page_name}: ${article_count} bloque(s), ${idevice_count} iDevice(s)"
    fi

    if ! grep -Eiq 'class="[^"]*package-title[^"]*"' "$html_file"; then
        warn "No se ha detectado .package-title en ${page_name}: el titulo general del recurso podria no mostrarse"
    fi
}

prepare_root() {
    local input_path="$1"
    local abs_input

    abs_input="$(abs_path "$input_path")"

    if [[ -d "$abs_input" ]]; then
        ROOT_DIR="$abs_input"
        TEMP_DIR=""
        if [[ -f "${ROOT_DIR}/.elpx-template" ]]; then
            IS_TEMPLATE_SOURCE=1
            warn "Se esta validando una plantilla fuente; los placeholders se trataran como avisos"
        fi
        ok "Validando directorio descomprimido"
        return 0
    fi

    if [[ -f "$abs_input" ]]; then
        require_cmd unzip
        TEMP_DIR="$(mktemp -d)"
        unzip -q "$abs_input" -d "$TEMP_DIR"
        ROOT_DIR="$TEMP_DIR"
        ok "Paquete descomprimido temporalmente"
        return 0
    fi

    echo "La ruta no existe: $abs_input" >&2
    exit 2
}

cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
}

main() {
    if [[ $# -ne 1 ]]; then
        usage
        exit 2
    fi

    prepare_root "$1"
    trap cleanup EXIT

    check_exists "$ROOT_DIR" "content.xml"
    check_exists "$ROOT_DIR" "content.dtd"
    check_exists "$ROOT_DIR" "index.html"
    check_exists "$ROOT_DIR" "content/css/base.css"
    check_exists "$ROOT_DIR" "libs"
    check_exists "$ROOT_DIR" "theme"
    check_exists "$ROOT_DIR" "idevices"

    if [[ -f "${ROOT_DIR}/content.xml" ]]; then
        validate_xml_basic "${ROOT_DIR}/content.xml"
        validate_didactic_minimum_structure "${ROOT_DIR}/content.xml"
        validate_text_idevice_sync "${ROOT_DIR}/content.xml"
    fi

    validate_unresolved_placeholders "$ROOT_DIR"
    validate_suspicious_example_content "$ROOT_DIR"

    local html_list
    html_list="$(mktemp)"
    {
        [[ -f "${ROOT_DIR}/index.html" ]] && printf '%s\n' "${ROOT_DIR}/index.html"
        if [[ -d "${ROOT_DIR}/html" ]]; then
            find "${ROOT_DIR}/html" -maxdepth 1 -type f \( -name '*.html' -o -name '*.xhtml' \) | sort
        fi
    } > "$html_list"

    if [[ ! -s "$html_list" ]]; then
        fail "No se han encontrado archivos HTML para validar"
    else
        while IFS= read -r html_file; do
            validate_html_structure "$html_file"
            validate_html_refs "$html_file"
        done < "$html_list"
    fi

    rm -f "$html_list"

    printf '\nResumen: %s fallo(s), %s aviso(s)\n' "$FAILURES" "$WARNINGS"

    if [[ "$FAILURES" -gt 0 ]]; then
        exit 1
    fi
}

ROOT_DIR=""
TEMP_DIR=""

main "$@"
