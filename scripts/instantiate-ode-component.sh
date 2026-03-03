#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REF_DIR="${REPO_DIR}/referencias/ode_components"

usage() {
    cat <<'EOF'
Uso:
  instantiate-ode-component.sh <tipo_idevice> [archivo_salida.xml]

Genera un snippet `odeComponent` listo para insertar en `content.xml`
a partir de `referencias/ode_components/<tipo>.xml`.

Sustituye automaticamente:
  - __PAGE_ID__
  - __BLOCK_ID__
  - __IDEVICE_ID__
  - __EVALUATION_ID__
  - __DATA_GAME__

Variables opcionales de entorno:
  PAGE_ID
  BLOCK_ID
  IDEVICE_ID
  EVALUATION_ID
  DATA_GAME

Si no se indican, se generan valores por defecto seguros.
EOF
}

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

generate_id() {
    local suffix="$1"
    printf '%s%s\n' "$(date +%Y%m%d%H%M%S)" "$suffix"
}

xml_escape_text() {
    printf '%s' "$1" \
        | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

json_escape_text() {
    printf '%s' "$1" \
        | sed 's/\\/\\\\/g; s/"/\\"/g'
}

replace_token() {
    local text="$1"
    local token="$2"
    local value="$3"
    python3 -c 'import sys; print(sys.stdin.read().replace(sys.argv[1], sys.argv[2]), end="")' \
        "$token" \
        "$value" <<< "$text"
}

normalize_known_ids() {
    local text="$1"
    local page_id="$2"
    local block_id="$3"
    local idevice_id="$4"
    local evaluation_id="$5"

    python3 -c '
import re
import sys

content = sys.stdin.read()
page_id, block_id, idevice_id, evaluation_id = sys.argv[1:5]

content = re.sub(r"<odePageId>.*?</odePageId>", f"<odePageId>{page_id}</odePageId>", content, count=1, flags=re.S)
content = re.sub(r"<odeBlockId>.*?</odeBlockId>", f"<odeBlockId>{block_id}</odeBlockId>", content, count=1, flags=re.S)
content = re.sub(r"<odeIdeviceId>.*?</odeIdeviceId>", f"<odeIdeviceId>{idevice_id}</odeIdeviceId>", content, count=1, flags=re.S)
content = re.sub(r"\"ideviceId\":\"[^\"]*\"", f"\"ideviceId\":\"{idevice_id}\"", content)
content = re.sub(r"data-id=\"[^\"]*\"", f"data-id=\"{idevice_id}\"", content)
content = re.sub(r"data-evaluationid=\"[^\"]*\"", f"data-evaluationid=\"{evaluation_id}\"", content)
content = re.sub(r"auto-geogebra-evaluation-id-[^\\s\\\"]+", f"auto-geogebra-evaluation-id-{evaluation_id}", content)
content = re.sub(r"auto-geogebra-ideviceid-[^\\s\\\"]+", f"auto-geogebra-ideviceid-{idevice_id}", content)

sys.stdout.write(content)
' "$page_id" "$block_id" "$idevice_id" "$evaluation_id" <<< "$text"
}

main() {
    if [[ "${1:-}" = "-h" || "${1:-}" = "--help" || "${1:-}" = "help" ]]; then
        usage
        exit 0
    fi

    if [[ $# -lt 1 || $# -gt 2 ]]; then
        usage
        exit 2
    fi

    local idevice_type="$1"
    local output_file="${2:-}"
    local ref_file="${REF_DIR}/${idevice_type}.xml"
    local page_id="${PAGE_ID:-$(generate_id PAGE01)}"
    local block_id="${BLOCK_ID:-$(generate_id BLK001)}"
    local idevice_id="${IDEVICE_ID:-$(generate_id IDEV01)}"
    local evaluation_id="${EVALUATION_ID:-$(generate_id EVAL01)}"
    local data_game_raw="${DATA_GAME:-{}}"
    local data_game_xml
    local template

    [[ -f "${ref_file}" ]] || fail "No existe la referencia: ${ref_file}"

    template="$(cat "${ref_file}")"
    data_game_xml="$(xml_escape_text "${data_game_raw}")"

    template="$(replace_token "${template}" "__PAGE_ID__" "${page_id}")"
    template="$(replace_token "${template}" "__BLOCK_ID__" "${block_id}")"
    template="$(replace_token "${template}" "__IDEVICE_ID__" "${idevice_id}")"
    template="$(replace_token "${template}" "__EVALUATION_ID__" "${evaluation_id}")"
    template="$(replace_token "${template}" "__DATA_GAME__" "${data_game_xml}")"
    template="$(normalize_known_ids "${template}" "${page_id}" "${block_id}" "${idevice_id}" "${evaluation_id}")"

    if grep -Eq '__[A-Z][A-Z0-9_]*__' <<< "${template}"; then
        fail "Quedan placeholders sin sustituir en el snippet generado"
    fi

    if [[ -n "${output_file}" ]]; then
        printf '%s\n' "${template}" > "${output_file}"
        printf 'Snippet generado en: %s\n' "${output_file}"
    else
        printf '%s\n' "${template}"
    fi
}

main "$@"
