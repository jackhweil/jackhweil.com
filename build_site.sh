#!/bin/bash

PROG_NAME=$(basename "$0")

help_menu () {
cat << EOF
Usage: ${PROG_NAME} -i=<input-dir> -o=<output-dir> -a=<asset-dir> -s=<style-dir>

Options:
-h, --help    display this screen

Params:
<input-dir>   directory to recursively search for .md files from
<output-dir>  directory to output html files in, mirroring <input-dir> structure
<asset-dir>   directory containing assets, will be copied into output site directory
<style-dir>   directory containing css, will be copied into output site directory

Example:
${PROG_NAME} -i=source -o=output -a=assets -s=css

Find all files with .md suffix in directory source (recursively) and create or overwrite output directory with
converted html files. Also copy directories assets and css into output.
EOF
}

main () {
    check_for_dependencies
    parse_opts "$@"
    build_site
}

check_for_dependencies () {
    # check for pandoc
    if ! command -v pandoc &>/dev/null; then
        echo "pandoc required but not found, exiting..."
        exit 1
    fi
}

parse_opts () {
    if [ $# -eq 0 ]; then
        echo "No arguments provided, exiting..."
        help_menu
        exit 1
    fi

    for arg in "$@"; do
        case "${arg}" in
            -h|--help)
                help_menu
                exit
                ;;
            -i=*|--input=*)
                INPUT_DIR="${arg#*=}"
                shift
                if [ ! -d "${INPUT_DIR}" ]; then
                    echo "Invalid input directory: ${INPUT_DIR}"
                    exit 1
                fi
                ;;
            -o=*|--output=*)
                OUTPUT_DIR="${arg#*=}"
                shift
                ;;
            -a=*|--assets=*)
                ASSET_DIR="${arg#*=}"
                shift
                if [ ! -d "${ASSET_DIR}" ]; then
                    echo "Invalid asset directory: ${ASSET_DIR}"
                    exit 1
                fi
                ;;
            -s=*|--style=*)
                STYLE_DIR="${arg#*=}"
                shift
                if [ ! -d "${STYLE_DIR}" ]; then
                    echo "Invalid asset directory: ${STYLE_DIR}"
                    exit 1
                fi
                ;;
            *)
                echo "Bad argument: ${arg}"
                help_menu
                exit 1
                ;;
        esac
    done
}

build_site () {
    # get all the markdown files we need to convert, treating header and footer separately
    mapfile -t INPUT_FILES < <(find "${INPUT_DIR}" \( -name "*.md" -and ! -name "header.md" -and ! -name "footer.md" \))

    # clear stale output
    if [ -d "${OUTPUT_DIR}" ]; then
        rm -rf "${OUTPUT_DIR}"
    fi
    mkdir -p "${OUTPUT_DIR}"

    # copy in non-html
    cp -r "${STYLE_DIR}" "${OUTPUT_DIR}/"
    cp -r "${ASSET_DIR}" "${OUTPUT_DIR}/"

    # process the special header and footer files
    HEADER_FILE_PATH="${OUTPUT_DIR}/header.html"
    FOOTER_FILE_PATH="${OUTPUT_DIR}/footer.html"
    if [ -f "${INPUT_DIR}/header.md" ]; then
        pandoc "${INPUT_DIR}/header.md" --output "${HEADER_FILE_PATH}" --to=html5
    else
        touch "${HEADER_FILE_PATH}"
    fi
    if [ -f "${INPUT_DIR}/footer.md" ]; then
        pandoc "${INPUT_DIR}/footer.md" --output "${FOOTER_FILE_PATH}" --to=html5
    else
        touch "${FOOTER_FILE_PATH}"
    fi

    # process and convert each input file
    for INPUT_FILE_PATH in "${INPUT_FILES[@]}"; do
        INPUT_PATH=$(dirname "${INPUT_FILE_PATH}")
        OUTPUT_PATH=${INPUT_PATH/$INPUT_DIR/$OUTPUT_DIR}
        INPUT_FILE=$(basename -- "${INPUT_FILE_PATH}")
        INPUT_NAME=${INPUT_FILE%.*}
        OUTPUT_FILE_PATH="${OUTPUT_PATH}/${INPUT_NAME}.html"
        mkdir -p "${OUTPUT_PATH}"
        pre_process_target "${INPUT_FILE_PATH}"
        convert_target "${OUTPUT_FILE_PATH}" "${INPUT_FILE_PATH}" "${HEADER_FILE_PATH}" "${FOOTER_FILE_PATH}"
        post_process_target "${OUTPUT_FILE_PATH}"
    done
}

convert_target () {
    pandoc "${2}" \
        --output="${1}" \
        --from=markdown \
        --to=html5 \
        --css="/$(basename -- "${STYLE_DIR}")/main.css" \
        --toc \
        --include-before-body="${3}" \
        --include-after-body="${4}" \
        --highlight-style=haddock \
        --standalone
}

pre_process_target () {
    # noop for now
    true
}

post_process_target () {
    update_links "${1}"
}

update_links () {
    # replace md file extension with html in href tags
    sed -i 's/href=\([^[:space:]]\+\)\.md">/href=\1\.html">/g' "${1}"
}

main "$@"
