#!/usr/bin/env bash

set -euo pipefail

DEFAULT_EXE_REPO="/home/jjdeharo/Documentos/github/exelearning"
EXE_REPO_DIR="${EXE_REPO_DIR:-$DEFAULT_EXE_REPO}"
IDEVICE_BASE_DIR="${EXE_REPO_DIR}/public/files/perm/idevices/base"

usage() {
    cat <<'EOF'
Uso:
  add-idevice-assets.sh list
  add-idevice-assets.sh list-presets
  add-idevice-assets.sh add <directorio_proyecto> <idevice> [idevice...]
  add-idevice-assets.sh add-preset <directorio_proyecto> <preset> [preset...]

Comandos:
  list         Muestra los iDevices disponibles en el clon local de eXe.
  list-presets Muestra los perfiles predefinidos.
  add          Copia los recursos de exportacion de uno o varios iDevices a un proyecto.
  add-preset   Añade un conjunto predefinido de iDevices.

Ejemplo:
  ./scripts/add-idevice-assets.sh add ./mi_proyecto guess crossword word-search
  ./scripts/add-idevice-assets.sh add-preset ./mi_proyecto juegos aula
EOF
}

abs_path() {
    local target="$1"
    if [[ "$target" = /* ]]; then
        printf '%s\n' "$target"
    else
        printf '%s\n' "$(pwd)/$target"
    fi
}

check_repo() {
    if [[ ! -d "${IDEVICE_BASE_DIR}" ]]; then
        echo "No se encuentra el repo de eXe en: ${EXE_REPO_DIR}" >&2
        echo "Puedes sobrescribirlo exportando EXE_REPO_DIR=/ruta/al/repo" >&2
        exit 2
    fi
}

list_idevices() {
    check_repo
    find "${IDEVICE_BASE_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

preset_members() {
    case "$1" in
        juegos)
            printf '%s\n' \
                az-quiz-game \
                classify \
                complete \
                crossword \
                dragdrop \
                flipcards \
                guess \
                hidden-image \
                identify \
                interactive-video \
                mathematicaloperations \
                mathproblems \
                padlock \
                periodic-table \
                puzzle \
                quick-questions \
                quick-questions-multiple-choice \
                quick-questions-video \
                relate \
                scrambled-list \
                sort \
                trivial \
                trueorfalse \
                word-search
            ;;
        aula)
            printf '%s\n' \
                beforeafter \
                casestudy \
                challenge \
                checklist \
                discover \
                download-source-file \
                example \
                external-website \
                form \
                geogebra-activity \
                image-gallery \
                magnifier \
                map \
                progress-report \
                rubric \
                select-media-files \
                text \
                udl-content
            ;;
        evaluacion)
            printf '%s\n' \
                checklist \
                form \
                progress-report \
                quick-questions \
                quick-questions-multiple-choice \
                quick-questions-video \
                rubric \
                trueorfalse
            ;;
        medios)
            printf '%s\n' \
                beforeafter \
                external-website \
                geogebra-activity \
                hidden-image \
                image-gallery \
                interactive-video \
                magnifier \
                map \
                select-media-files
            ;;
        all)
            list_idevices
            ;;
        *)
            return 1
            ;;
    esac
}

list_presets() {
    cat <<'EOF'
juegos
aula
evaluacion
medios
all
EOF
}

copy_idevice() {
    local project_dir="$1"
    local idevice="$2"
    local source_dir="${IDEVICE_BASE_DIR}/${idevice}/export"
    local dest_dir="${project_dir}/idevices/${idevice}"

    if [[ ! -d "${source_dir}" ]]; then
        echo "[FAIL] No existe el iDevice '${idevice}' en ${source_dir}" >&2
        return 1
    fi

    mkdir -p "${dest_dir}"

    find "${source_dir}" -maxdepth 1 -type f ! -name '*.test.js' ! -name '*.spec.js' -print0 \
        | while IFS= read -r -d '' file; do
            cp "${file}" "${dest_dir}/"
        done

    echo "[OK] Recursos añadidos: idevices/${idevice}"
    return 0
}

add_idevices() {
    local project_dir="$1"
    shift
    local project_abs
    local failures=0

    check_repo
    project_abs="$(abs_path "$project_dir")"

    if [[ ! -d "${project_abs}" ]]; then
        echo "No existe el directorio de proyecto: ${project_abs}" >&2
        exit 2
    fi

    mkdir -p "${project_abs}/idevices"

    for idevice in "$@"; do
        if ! copy_idevice "${project_abs}" "${idevice}"; then
            failures=$((failures + 1))
        fi
    done

    if [[ "${failures}" -gt 0 ]]; then
        exit 1
    fi
}

add_presets() {
    local project_dir="$1"
    shift
    local tmp_file
    local preset
    local idevice
    local failures=0

    check_repo
    tmp_file="$(mktemp)"

    for preset in "$@"; do
        if ! preset_members "$preset" > "${tmp_file}.preset"; then
            echo "[FAIL] Preset desconocido: ${preset}" >&2
            failures=$((failures + 1))
            continue
        fi
        cat "${tmp_file}.preset" >> "$tmp_file"
    done

    if [[ "$failures" -gt 0 ]]; then
        rm -f "${tmp_file}" "${tmp_file}.preset"
        exit 1
    fi

    sort -u "$tmp_file" -o "$tmp_file"

    while IFS= read -r idevice; do
        [[ -z "$idevice" ]] && continue
        if ! copy_idevice "$(abs_path "$project_dir")" "$idevice"; then
            failures=$((failures + 1))
        fi
    done < "$tmp_file"

    rm -f "${tmp_file}" "${tmp_file}.preset"

    if [[ "$failures" -gt 0 ]]; then
        exit 1
    fi
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 2
    fi

    case "$1" in
        list)
            if [[ $# -ne 1 ]]; then
                usage
                exit 2
            fi
            list_idevices
            ;;
        list-presets)
            if [[ $# -ne 1 ]]; then
                usage
                exit 2
            fi
            list_presets
            ;;
        add)
            if [[ $# -lt 3 ]]; then
                usage
                exit 2
            fi
            shift
            add_idevices "$@"
            ;;
        add-preset)
            if [[ $# -lt 3 ]]; then
                usage
                exit 2
            fi
            shift
            add_presets "$@"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

main "$@"
