#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_EXE_REPO="/home/jjdeharo/Documentos/github/exelearning"
EXE_REPO_DIR="${EXE_REPO_DIR:-$DEFAULT_EXE_REPO}"
IDEVICE_BASE_DIR="${EXE_REPO_DIR}/public/files/perm/idevices/base"
FIXTURES_DIR="${EXE_REPO_DIR}/test/fixtures"
OUT_DIR="${REPO_DIR}/referencias/ode_components"
CURATED_DIR="${REPO_DIR}/referencias/ode_components_curated"
OUT_MD="${REPO_DIR}/catalogo_componentes_ode.md"

usage() {
    cat <<'EOF'
Uso:
  generate-ode-component-examples.sh

Genera:
  - referencias/ode_components/<tipo>.xml
  - catalogo_componentes_ode.md

Los ejemplos se extraen de content.xml reales presentes en los fixtures del clon local de eXe.
Si existe una referencia curada en referencias/ode_components_curated/, esa tiene prioridad.
EOF
}

check_repo() {
    if [[ ! -d "${IDEVICE_BASE_DIR}" ]]; then
        echo "No se encuentra la base de iDevices en: ${IDEVICE_BASE_DIR}" >&2
        exit 2
    fi
    if [[ ! -d "${FIXTURES_DIR}" ]]; then
        echo "No se encuentran los fixtures en: ${FIXTURES_DIR}" >&2
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

generate_stub_component() {
    local idevice="$1"
    local config_file="$2"
    local out_file="$3"
    local css_class="$idevice"
    local component_type="html"
    local template_name="${idevice}.html"

    if [[ -f "${config_file}" ]]; then
        local config_css_class
        local config_component_type
        local config_template_name
        config_css_class="$(xml_tag_value "${config_file}" "css-class")"
        config_component_type="$(xml_tag_value "${config_file}" "component-type")"
        config_template_name="$(xml_tag_value "${config_file}" "export-template-filename")"
        [[ -n "${config_css_class}" ]] && css_class="${config_css_class}"
        [[ -n "${config_component_type}" ]] && component_type="${config_component_type}"
        [[ -n "${config_template_name}" ]] && template_name="${config_template_name}"
    fi

    {
        printf '<!-- GENERATED STUB: revisar con un ejemplo real si se necesita fidelidad total -->\n'
        printf '<odeComponent>\n'
        printf '  <odePageId>__PAGE_ID__</odePageId>\n'
        printf '  <odeBlockId>__BLOCK_ID__</odeBlockId>\n'
        printf '  <odeIdeviceId>__IDEVICE_ID__</odeIdeviceId>\n'
        printf '  <odeIdeviceTypeName>%s</odeIdeviceTypeName>\n' "${idevice}"
        printf '  <htmlView><![CDATA[<div class="%s">Contenido de ejemplo para %s</div>]]></htmlView>\n' "${css_class}" "${idevice}"
        if [[ "${component_type}" = "json" ]]; then
            printf '  <jsonProperties><![CDATA[{"ideviceId":"__IDEVICE_ID__","template":"%s","type":"%s"}]]></jsonProperties>\n' "${template_name}" "${idevice}"
        else
            printf '  <jsonProperties></jsonProperties>\n'
        fi
        printf '  <odeComponentsOrder>1</odeComponentsOrder>\n'
        printf '  <odeComponentsProperties>\n'
        printf '    <odeComponentsProperty>\n'
        printf '      <key>visibility</key>\n'
        printf '      <value>true</value>\n'
        printf '    </odeComponentsProperty>\n'
        printf '  </odeComponentsProperties>\n'
        printf '</odeComponent>\n'
    } > "${out_file}"
}

extract_first_component() {
    local xml_file="$1"
    local idevice_type="$2"
    local out_file="$3"

    perl -0e '
        my ($type, $file) = @ARGV;
        local $/ = undef;
        open my $fh, q{<}, $file or exit 1;
        my $content = <$fh>;
        close $fh;
        while ($content =~ m{(<odeComponent>.*?</odeComponent>)}sg) {
            my $block = $1;
            if ($block =~ m{<odeIdeviceTypeName>\Q$type\E</odeIdeviceTypeName>}s) {
                print $block;
                exit 0;
            }
        }
        exit 1;
    ' "$idevice_type" "$xml_file" > "$out_file"
}

main() {
    check_repo

    rm -rf "${OUT_DIR}"
    mkdir -p "${OUT_DIR}"

    local idevice_dirs=()
    local content_files=()
    mapfile -t idevice_dirs < <(find "${IDEVICE_BASE_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
    mapfile -t content_files < <(find "${FIXTURES_DIR}" -name content.xml | sort)

    {
        printf '# Catalogo de ejemplos ODE por iDevice\n\n'
        printf 'Este catalogo combina tres tipos de referencias:\n\n'
        printf -- '- `curated`: referencias manuales del propio kit, afinadas para servir como modelo practico\n'
        printf -- '- `real`: extraidas de `content.xml` reales de los fixtures locales de eXe\n'
        printf -- '- `generated`: generadas a partir de `config.xml` cuando no existe aun un ejemplo real\n\n'
        printf 'La prioridad correcta es `curated` > `real` > `generated`.\n\n'
        printf 'Las referencias `generated` sirven como esqueleto estructural, pero deben sustituirse por ejemplos reales cuando se necesite fidelidad total.\n\n'
        printf '## Tabla\n\n'
        printf '| Tipo | Titulo | Categoria | Referencia | Fuente |\n'
        printf '| :--- | :--- | :--- | :--- | :--- |\n'
    } > "${OUT_MD}"

    local idevice
    for idevice in "${idevice_dirs[@]}"; do
        local config_file="${IDEVICE_BASE_DIR}/${idevice}/config.xml"
        local title="${idevice}"
        local category="-"
        local reference_type="generated"
        local snippet_file="${OUT_DIR}/${idevice}.xml"
        local source_rel="config.xml"
        local xml_file
        local curated_file="${CURATED_DIR}/${idevice}.xml"

        if [[ -f "${config_file}" ]]; then
            local config_title
            local config_category
            config_title="$(xml_tag_value "${config_file}" title)"
            config_category="$(xml_tag_value "${config_file}" category)"
            [[ -n "${config_title}" ]] && title="${config_title}"
            [[ -n "${config_category}" ]] && category="${config_category}"
        fi

        rm -f "${snippet_file}"

        if [[ -f "${curated_file}" ]]; then
            cp "${curated_file}" "${snippet_file}"
            reference_type="curated"
            source_rel="${curated_file#${REPO_DIR}/}"
        else
            for xml_file in "${content_files[@]}"; do
                if grep -q "<odeIdeviceTypeName>${idevice}</odeIdeviceTypeName>" "${xml_file}"; then
                    if extract_first_component "${xml_file}" "${idevice}" "${snippet_file}"; then
                        reference_type="real"
                        source_rel="${xml_file#${EXE_REPO_DIR}/}"
                        break
                    fi
                fi
            done
        fi

        if [[ "${reference_type}" = "generated" ]]; then
            generate_stub_component "${idevice}" "${config_file}" "${snippet_file}"
            source_rel="${config_file#${EXE_REPO_DIR}/}"
        fi

        printf '| `%s` | %s | %s | %s | `%s` |\n' \
            "${idevice}" \
            "${title}" \
            "${category}" \
            "${reference_type}" \
            "${source_rel}" >> "${OUT_MD}"
    done

    printf 'Ejemplos generados en:\n- %s\n- %s\n' "${OUT_DIR}" "${OUT_MD}"
}

if [[ "${1:-}" = "-h" || "${1:-}" = "--help" || "${1:-}" = "help" ]]; then
    usage
    exit 0
fi

main
