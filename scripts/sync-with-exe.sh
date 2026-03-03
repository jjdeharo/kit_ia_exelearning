#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_EXE_REPO="/home/jjdeharo/Documentos/github/exelearning"
EXE_REPO_DIR="${EXE_REPO_DIR:-$DEFAULT_EXE_REPO}"

usage() {
    cat <<'EOF'
Uso:
  sync-with-exe.sh

Hace una resincronizacion basica del kit tras actualizar eXe:

  1. Regenera el catalogo de iDevices
  2. Regenera las referencias ODE
  3. Valida las plantillas fuente
  4. Valida los .elpx de referencia
  5. Resume el estado del catalogo ODE

Se puede cambiar el repo de eXe con:
  EXE_REPO_DIR=/ruta/al/repo ./scripts/sync-with-exe.sh
EOF
}

require_file() {
    local path="$1"
    if [[ ! -e "$path" ]]; then
        echo "Falta el archivo requerido: $path" >&2
        exit 2
    fi
}

run_step() {
    local label="$1"
    shift
    printf '\n== %s ==\n' "$label"
    "$@"
}

summarize_ode_catalog() {
    local catalog_file="${REPO_DIR}/catalogo_componentes_ode.md"

    require_file "$catalog_file"

    python3 - "$catalog_file" <<'PY'
from pathlib import Path
import sys

catalog = Path(sys.argv[1]).read_text(encoding="utf-8")
counts = {"curated": 0, "real": 0, "generated": 0}
generated = []

for line in catalog.splitlines():
    if not line.startswith("| `"):
        continue
    parts = [p.strip() for p in line.strip("|").split("|")]
    if len(parts) < 4:
        continue
    idevice = parts[0].strip("`")
    ref = parts[3]
    if ref in counts:
        counts[ref] += 1
    if ref == "generated":
        generated.append(idevice)

print(f"Resumen ODE: curated={counts['curated']}, real={counts['real']}, generated={counts['generated']}")
if generated:
    print("iDevices en generated:")
    for item in generated:
        print(f"- {item}")
else:
    print("No hay iDevices en generated.")
PY
}

main() {
    if [[ "${1:-}" = "-h" || "${1:-}" = "--help" || "${1:-}" = "help" ]]; then
        usage
        exit 0
    fi

    if [[ $# -ne 0 ]]; then
        usage
        exit 2
    fi

    require_file "${SCRIPT_DIR}/generate-idevice-catalog.sh"
    require_file "${SCRIPT_DIR}/generate-ode-component-examples.sh"
    require_file "${SCRIPT_DIR}/validate-elpx.sh"

    if [[ ! -d "${EXE_REPO_DIR}" ]]; then
        echo "No se encuentra el repo de eXe en: ${EXE_REPO_DIR}" >&2
        exit 2
    fi

    printf 'Repo de eXe usado: %s\n' "${EXE_REPO_DIR}"

    run_step "Regenerar catalogo de iDevices" "${SCRIPT_DIR}/generate-idevice-catalog.sh"
    run_step "Regenerar referencias ODE" "${SCRIPT_DIR}/generate-ode-component-examples.sh"

    run_step "Validar plantillas fuente" "${SCRIPT_DIR}/validate-elpx.sh" "${REPO_DIR}/plantillas/plantilla_base_minima"
    run_step "Validar plantillas fuente" "${SCRIPT_DIR}/validate-elpx.sh" "${REPO_DIR}/plantillas/plantilla_avanzada_aula"
    run_step "Validar plantillas fuente" "${SCRIPT_DIR}/validate-elpx.sh" "${REPO_DIR}/plantillas/plantilla_todos_idevices"

    run_step "Validar paquetes .elpx" "${SCRIPT_DIR}/validate-elpx.sh" "${REPO_DIR}/plantillas/plantilla_base_minima.elpx"
    run_step "Validar paquetes .elpx" "${SCRIPT_DIR}/validate-elpx.sh" "${REPO_DIR}/plantillas/plantilla_avanzada_aula.elpx"
    run_step "Validar paquetes .elpx" "${SCRIPT_DIR}/validate-elpx.sh" "${REPO_DIR}/plantillas/plantilla_todos_idevices.elpx"

    printf '\n== Resumen final ==\n'
    summarize_ode_catalog
}

main "$@"
