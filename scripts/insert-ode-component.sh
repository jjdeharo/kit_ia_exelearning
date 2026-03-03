#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTANTIATE_SCRIPT="${SCRIPT_DIR}/instantiate-ode-component.sh"
CATALOG_JSON="${REPO_DIR}/catalogo_idevices.json"

usage() {
    cat <<'EOF'
Uso:
  insert-ode-component.sh [--page-id ID | --page-title TITULO] <directorio_proyecto> <tipo_idevice>

Inserta un nuevo bloque en:
  - content.xml
  - la pagina HTML correspondiente

El bloque se genera a partir de `referencias/ode_components/<tipo>.xml`
y queda listo para formar parte del proyecto.

Requisitos:
  - el proyecto debe existir
  - el proyecto debe contener content.xml e index.html
  - deben existir los assets en idevices/<tipo>/

Variables opcionales de entorno:
  DATA_GAME
  EVALUATION_ID
  BLOCK_TITLE
EOF
}

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

TMP_COMPONENT=""

cleanup() {
    if [[ -n "${TMP_COMPONENT:-}" && -f "${TMP_COMPONENT}" ]]; then
        rm -f "${TMP_COMPONENT}"
    fi
}

main() {
    if [[ "${1:-}" = "-h" || "${1:-}" = "--help" || "${1:-}" = "help" ]]; then
        usage
        exit 0
    fi

    local page_id_arg=""
    local page_title_arg=""
    local args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --page-id)
                [[ $# -ge 2 ]] || fail "Falta el valor de --page-id"
                page_id_arg="$2"
                shift 2
                ;;
            --page-title)
                [[ $# -ge 2 ]] || fail "Falta el valor de --page-title"
                page_title_arg="$2"
                shift 2
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    [[ -z "${page_id_arg}" || -z "${page_title_arg}" ]] || fail "Usa solo una de estas opciones: --page-id o --page-title"

    if [[ ${#args[@]} -ne 2 ]]; then
        usage
        exit 2
    fi

    local project_dir="${args[0]}"
    local idevice_type="${args[1]}"
    local content_xml="${project_dir}/content.xml"
    local idevice_dir="${project_dir}/idevices/${idevice_type}"

    [[ -d "${project_dir}" ]] || fail "No existe el proyecto: ${project_dir}"
    [[ -f "${content_xml}" ]] || fail "Falta content.xml en: ${project_dir}"
    [[ -f "${project_dir}/index.html" ]] || fail "Falta index.html en: ${project_dir}"
    [[ -d "${idevice_dir}" ]] || fail "Faltan los assets del iDevice: ${idevice_dir}"
    [[ -x "${INSTANTIATE_SCRIPT}" ]] || fail "No se puede ejecutar: ${INSTANTIATE_SCRIPT}"

    TMP_COMPONENT="$(mktemp)"
    trap cleanup EXIT

    "${INSTANTIATE_SCRIPT}" "${idevice_type}" "${TMP_COMPONENT}"

    python3 - "$content_xml" "$TMP_COMPONENT" "$idevice_type" "$CATALOG_JSON" "$project_dir" "$page_id_arg" "$page_title_arg" <<'PY'
from pathlib import Path
from datetime import datetime
import html
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

content_path = Path(sys.argv[1])
component_path = Path(sys.argv[2])
idevice_type = sys.argv[3]
catalog_path = Path(sys.argv[4])
project_dir = Path(sys.argv[5])
page_id_arg = sys.argv[6].strip()
page_title_arg = sys.argv[7].strip()

NS_URI = "http://www.intef.es/xsd/ode"
ns = {"ode": NS_URI}
ET.register_namespace("", NS_URI)

def q(tag: str) -> str:
    return f"{{{NS_URI}}}{tag}"

def apply_ns(el: ET.Element) -> None:
    if not el.tag.startswith("{"):
        el.tag = q(el.tag)
    for child in list(el):
        apply_ns(child)

content_text = content_path.read_text(encoding="utf-8")
component_text = component_path.read_text(encoding="utf-8")

content_root = ET.fromstring(content_text)
component_root = ET.fromstring(component_text)
apply_ns(component_root)

nav_structures = content_root.findall(".//ode:odeNavStructure", ns)
if not nav_structures:
    raise SystemExit("No se ha encontrado odeNavStructure en content.xml")

def clean_text(value: str | None) -> str:
    return (value or "").strip()

selected_nav = None
available_pages = []
for item in nav_structures:
    item_page_id = clean_text(item.findtext("ode:odePageId", None, ns))
    item_title = clean_text(item.findtext("ode:pageName", None, ns))
    if not item_title:
        item_title = clean_text(item.findtext("ode:odeNavStructureProperties/ode:odeNavStructureProperty[ode:key='titlePage']/ode:value", None, ns))
    available_pages.append((item_page_id, item_title))
    if page_id_arg and item_page_id == page_id_arg:
        selected_nav = item
    elif page_title_arg and item_title == page_title_arg:
        selected_nav = item

if selected_nav is None:
    if page_id_arg:
        raise SystemExit(f"No existe la pagina con id: {page_id_arg}")
    if page_title_arg:
        raise SystemExit(f"No existe la pagina con titulo: {page_title_arg}")
    if len(nav_structures) > 1:
        options = ", ".join(
            f"{page_id} ({title or 'sin titulo'})" for page_id, title in available_pages
        )
        raise SystemExit(
            "El proyecto tiene varias paginas. Indica una pagina destino con "
            f"--page-id o --page-title. Disponibles: {options}"
        )
    selected_nav = nav_structures[0]

nav_structure = selected_nav
page_id_el = nav_structure.find("ode:odePageId", ns)
if page_id_el is None or not (page_id_el.text or "").strip():
    raise SystemExit("No se ha encontrado odePageId en content.xml")
page_id = (page_id_el.text or "").strip()

pag_structures = nav_structure.find("ode:odePagStructures", ns)
if pag_structures is None:
    raise SystemExit("No se ha encontrado odePagStructures en content.xml")

existing_orders = []
existing_block_ids = set()
for item in pag_structures.findall("ode:odePagStructure", ns):
    order_el = item.find("ode:odePagStructureOrder", ns)
    if order_el is not None and (order_el.text or "").strip().isdigit():
        existing_orders.append(int((order_el.text or "").strip()))
    block_el = item.find("ode:odeBlockId", ns)
    if block_el is not None and (block_el.text or "").strip():
        existing_block_ids.add((block_el.text or "").strip())
next_order = max(existing_orders or [0]) + 1

stamp = datetime.now().strftime("%Y%m%d%H%M%S")

# IDs must be globally unique within content.xml (not only within a page).
all_block_ids = {clean_text(el.text) for el in content_root.findall(".//ode:odeBlockId", ns) if clean_text(el.text)}
all_idevice_ids = {clean_text(el.text) for el in content_root.findall(".//ode:odeIdeviceId", ns) if clean_text(el.text)}

component_block_id = f"{stamp}BLK{next_order:03d}"
component_idevice_id = f"{stamp}IDEV{next_order:03d}"
evaluation_id = os.environ.get("EVALUATION_ID", f"{stamp}EVAL{next_order:03d}")

suffix = 0
while component_block_id in all_block_ids or component_idevice_id in all_idevice_ids:
    suffix += 1
    component_block_id = f"{stamp}BLK{next_order:03d}{suffix:02d}"
    component_idevice_id = f"{stamp}IDEV{next_order:03d}{suffix:02d}"
    if "EVALUATION_ID" not in os.environ:
        evaluation_id = f"{stamp}EVAL{next_order:03d}{suffix:02d}"

old_page_id = (component_root.findtext(q("odePageId")) or "").strip()
old_block_id = (component_root.findtext(q("odeBlockId")) or "").strip()
old_idevice_id = (component_root.findtext(q("odeIdeviceId")) or "").strip()

block_title = os_environ_title = None
block_title = os.environ.get("BLOCK_TITLE")
if not block_title:
    if catalog_path.is_file():
        try:
            catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
            for item in catalog:
                if item.get("type") == idevice_type:
                    block_title = item.get("title")
                    break
        except Exception:
            block_title = None
if not block_title:
    block_title = idevice_type

def force_component_text(el_name: str, value: str) -> None:
    el = component_root.find(q(el_name))
    if el is not None:
        el.text = value

force_component_text("odePageId", page_id)
force_component_text("odeBlockId", component_block_id)
force_component_text("odeIdeviceId", component_idevice_id)

for text_el_name in ("htmlView", "jsonProperties"):
    el = component_root.find(q(text_el_name))
    if el is None or el.text is None:
        continue
    txt = el.text
    if old_page_id:
        txt = txt.replace(old_page_id, page_id)
    if old_block_id:
        txt = txt.replace(old_block_id, component_block_id)
    if old_idevice_id:
        txt = txt.replace(old_idevice_id, component_idevice_id)
    txt = re.sub(r"\"ideviceId\":\"[^\"]*\"", f"\"ideviceId\":\"{component_idevice_id}\"", txt)
    txt = re.sub(r"data-id=\"[^\"]*\"", f"data-id=\"{component_idevice_id}\"", txt)
    txt = re.sub(r"data-evaluationid=\"[^\"]*\"", f"data-evaluationid=\"{evaluation_id}\"", txt)
    txt = re.sub(r"auto-geogebra-evaluation-id-[^\s\\\"]+", f"auto-geogebra-evaluation-id-{evaluation_id}", txt)
    txt = re.sub(r"auto-geogebra-ideviceid-[^\s\\\"]+", f"auto-geogebra-ideviceid-{component_idevice_id}", txt)
    el.text = txt

new_block = ET.Element(q("odePagStructure"))

def sub(parent, tag, text):
    el = ET.SubElement(parent, q(tag))
    el.text = text
    return el

sub(new_block, "odePageId", page_id)
sub(new_block, "odeBlockId", component_block_id)
sub(new_block, "blockName", block_title)
sub(new_block, "iconName", "")
sub(new_block, "odePagStructureOrder", str(next_order))

props = ET.SubElement(new_block, q("odePagStructureProperties"))
for key, value in [
    ("visibility", "true"),
    ("teacherOnly", "false"),
    ("allowToggle", "true"),
    ("minimized", "false"),
]:
    prop = ET.SubElement(props, q("odePagStructureProperty"))
    sub(prop, "key", key)
    sub(prop, "value", value)

components = ET.SubElement(new_block, q("odeComponents"))

order_el = component_root.find(q("odeComponentsOrder"))
if order_el is not None:
    order_el.text = "1"
components.append(component_root)
pag_structures.append(new_block)

new_content = ET.tostring(content_root, encoding="unicode")
if content_text.startswith('<?xml version="1.0" encoding="UTF-8"?>'):
    new_content = '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE ode SYSTEM "content.dtd">\n' + new_content
content_path.write_text(new_content, encoding="utf-8")

target_html = None
candidate_files = [project_dir / "index.html"]
html_dir = project_dir / "html"
if html_dir.is_dir():
    candidate_files.extend(sorted(html_dir.glob("*.html")))

# Depending on eXe export version/theme, the page id can appear as:
# - id="<odePageId>"
# - id="page-content-<odePageId>"
main_markers = [
    f'id="{page_id}"',
    f'id="page-content-{page_id}"',
]
for candidate in candidate_files:
    try:
        candidate_text = candidate.read_text(encoding="utf-8")
    except OSError:
        continue
    if any(marker in candidate_text for marker in main_markers):
        target_html = candidate
        break

if target_html is None:
    raise SystemExit(f"No se ha encontrado el HTML de la pagina con id: {page_id}")

html_el = component_root.find(q("htmlView"))
html_view = ""
if html_el is not None and html_el.text:
    html_view = html.unescape(html_el.text)

page_text = target_html.read_text(encoding="utf-8")

is_root_page = target_html.resolve() == (project_dir / "index.html").resolve()
asset_prefix = "" if is_root_page else "../"

# In content.xml, text iDevices usually keep {{context_path}}/<folder>/<file>.
# For exported HTML pages that open directly in browser, this placeholder must be
# resolved to the actual relative path under content/resources/.
if "{{context_path}}/" in html_view:
    html_view = html_view.replace("{{context_path}}/", f"{asset_prefix}content/resources/")

js_tag = f'<script src="{asset_prefix}idevices/{idevice_type}/{idevice_type}.js"> </script>'
css_tag = f'<link rel="stylesheet" href="{asset_prefix}idevices/{idevice_type}/{idevice_type}.css">'

js_file = project_dir / "idevices" / idevice_type / f"{idevice_type}.js"
css_file = project_dir / "idevices" / idevice_type / f"{idevice_type}.css"

base_css_markers = [
    f'<link rel="stylesheet" href="{asset_prefix}content/css/base.css">',
    f'<link rel="stylesheet" type="text/css" href="{asset_prefix}content/css/base.css">',
]
base_css_marker = next((m for m in base_css_markers if m in page_text), None)
if base_css_marker is None:
    raise SystemExit(f"No se ha encontrado el punto de insercion de assets en: {target_html}")

if js_file.exists() and js_tag not in page_text:
    if base_css_marker in page_text:
        page_text = page_text.replace(base_css_marker, js_tag + "\n" + base_css_marker, 1)
    else:
        raise SystemExit(f"No se ha encontrado el punto de insercion para JS en: {target_html}")

if css_file.exists() and css_tag not in page_text:
    if base_css_marker in page_text:
        page_text = page_text.replace(base_css_marker, css_tag + "\n" + base_css_marker, 1)
    else:
        raise SystemExit(f"No se ha encontrado el punto de insercion para CSS en: {target_html}")

article_html = (
    f'<article id="{component_block_id}" class="box">\n'
    f'<header class="box-head">\n'
    f'<div class="box-icon exe-icon">\n'
    f'<img src="{asset_prefix}theme/icons/pieces.png" alt="">\n'
    f'</div>\n'
    f'<h1 class="box-title">{html.escape(block_title)}</h1>\n'
    f'<button class="box-toggle box-toggle-on" title="Toggle content"><span>Toggle content</span></button>\n'
    f'</header>\n'
    f'<div class="box-content">\n'
    f'<div id="{component_idevice_id}" class="idevice_node {idevice_type}" data-idevice-path="{asset_prefix}idevices/{idevice_type}/" data-idevice-type="{idevice_type}" data-idevice-component-type="json">\n'
    f'{html_view}\n'
    f'</div>\n'
    f'</div>\n'
    f'</article>'
)

page_content_end = re.search(r"</div>\s*</main>", page_text)
if not page_content_end:
    raise SystemExit(f"No se ha encontrado el punto de insercion de bloques en: {target_html}")

insert_at = page_content_end.start()
page_text = page_text[:insert_at] + "\n" + article_html + "\n" + page_text[insert_at:]
target_html.write_text(page_text, encoding="utf-8")

print(f"Bloque insertado: {idevice_type}")
print(f"- page_id: {page_id}")
print(f"- html_file: {target_html}")
print(f"- block_id: {component_block_id}")
print(f"- idevice_id: {component_idevice_id}")
PY
}

main "$@"
