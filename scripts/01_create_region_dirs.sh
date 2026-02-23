#!/bin/bash

set -euo pipefail

# Path to your interval files
INTERVALS_DIR="/gpfs/data/user/shweta_lab/data/SKAN/analyses/Scripts/Joint_callng/parralel_JC/intervals"

# Final output base directory
OUTPUT_DIR="split_gvcfs"

# Create the base output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Loop through each interval file and make a directory
for interval_file in "$INTERVALS_DIR"/*.interval_list; do
    interval_name=$(basename "$interval_file" .interval_list)
    mkdir -p "$OUTPUT_DIR/$interval_name"
    echo "Created: $OUTPUT_DIR/$interval_name"
done

echo "All region directories created."
