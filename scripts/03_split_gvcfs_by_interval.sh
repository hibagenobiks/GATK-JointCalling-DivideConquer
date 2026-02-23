#!/bin/bash
#SBATCH --output=split.%J.out
#SBATCH --error=split.%J.err

#SBATCH --exclusive
#SBATCH --job-name=split
#SBATCH --ntasks-per-node=72
#SBATCH --mem-per-cpu=180G
#SBATCH -N 1

set -euo pipefail

module load bcftools-1.21

# === PATHS ===
GVCF_DIR="/path/to/per-sample-gvcfs"
INTERVALS_DIR="/path/to/intervals"
OUTPUT_BASE="/path/to/split_gvcfs"
SAMPLE_LIST="sample_names.txt"  # File containing all sample names

# === LOOP OVER ALL SAMPLES ===
while IFS= read -r SAMPLE_NAME; do
    GVCF="$GVCF_DIR/${SAMPLE_NAME}.g.vcf.gz"

    echo "Checking for GVCF at: $GVCF"

    if [[ ! -f "$GVCF" ]]; then
        echo "GVCF for $SAMPLE_NAME not found, skipping"
        continue
    fi

    echo "Starting: $SAMPLE_NAME"

    # === LOOP OVER INTERVAL FILES ===
    for interval_file in "$INTERVALS_DIR"/*.interval_list; do
        interval_name=$(basename "$interval_file" .interval_list)
        output_dir="$OUTPUT_BASE/$interval_name"
        output_gvcf="$output_dir/${SAMPLE_NAME}_${interval_name}.g.vcf.gz"

        echo " ➤ Splitting $SAMPLE_NAME for $interval_name"

        bcftools view -R "$interval_file" "$GVCF" -O z -o "$output_gvcf"

        if [[ -f "$output_gvcf" ]]; then
            echo " Created: $output_gvcf"
        else
            echo " Failed: $output_gvcf"
        fi
    done

    echo "Finished: $SAMPLE_NAME"
done < "$SAMPLE_LIST"

echo "All samples in $SAMPLE_LIST processed!"
