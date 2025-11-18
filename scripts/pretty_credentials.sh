#!/usr/bin/env bash
set -euo pipefail

# Usage check
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input_file> <output_dir> <output_file>"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_DIR="$2"
OUTPUT_FILE="$3"

# Validate input file
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: input file not found: $INPUT_FILE"
    exit 1
fi

# Ensure output dir exists
mkdir -p "$OUTPUT_DIR"

# Pretty print JSON using jq
jq '.' "$INPUT_FILE" > "${OUTPUT_DIR}/${OUTPUT_FILE}"

echo "Formatted JSON written to: ${OUTPUT_DIR}/${OUTPUT_FILE}"
