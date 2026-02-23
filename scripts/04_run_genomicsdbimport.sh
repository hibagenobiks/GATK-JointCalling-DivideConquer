#!/bin/bash

# --- SBATCH Directives for the Manager Job ---
#SBATCH --job-name=GATK_DBImport_Manager
#SBATCH --output=pipeline_manager.%J.out
#SBATCH --error=pipeline_manager.%J.err
#SBATCH --partition= --   # Use a suitable partition for this lightweight manager job
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G

# #############################################################################
# ### GATK GenomicsDBImport Pipeline Manager                                ###
# #############################################################################

# --- Pipeline Configuration ---
echo "--- Initializing Pipeline Configuration ---"

# --- SLURM & Job Management ---
MAX_CONCURRENT_JOBS=28
SLEEP_INTERVAL=120
USERNAME=$(whoami)
# MODIFIED: Array of partitions to cycle through for worker jobs
PARTITIONS=("cbr_q_large" "cbr_q_huge") - Use available partitions in your HPC

# --- Data & Sanity Checks ---
MAIN_GVCF_DIR="/path/to/split_gvcfs"
EXPECTED_GVCF_COUNT= Total number of per sample gvcfs

# --- Path to Source Interval Files ---
INTERVALS_SOURCE_DIR="/path/to/intervals"

# --- Module Loading ---
echo "--- Loading required modules ---"
module load gatk/4.4.0.0
module load bcftools-1.21

echo "======================================================="
echo "### GATK DBImport Pipeline Manager Started: $(date) ###"
echo "### User: $USERNAME"
echo "### Max Concurrent Jobs: $MAX_CONCURRENT_JOBS"
echo "### Distributing jobs across partitions: ${PARTITIONS[*]}"
echo "======================================================="

# MODIFIED: Initialize a counter for cycling through partitions
job_counter=0

# --- Main Pipeline Logic ---
for chunk_dir_path in ${MAIN_GVCF_DIR}/chr*_part*/; do
    if [ ! -d "$chunk_dir_path" ]; then
        echo "Warning: No chunk directories found matching the pattern. Exiting."
        continue
    fi

    part_name=$(basename "$chunk_dir_path")
    echo -e "\n---==================== Processing: $part_name ====================---"

    # --- SANITY CHECKS ---
    sanity_checks_passed=true
    # ... [Sanity checks remain the same] ...
    # 1. Check for the correct number of gVCF files
    echo "[CHECK 1] Verifying gVCF file count in $part_name..."
    actual_gvcf_count=$(find "$chunk_dir_path" -maxdepth 1 -type f -name "*.g.vcf.gz" | wc -l)

    if [ "$actual_gvcf_count" -ne "$EXPECTED_GVCF_COUNT" ]; then
        echo "  [FAIL] Expected $EXPECTED_GVCF_COUNT files, but found $actual_gvcf_count."
        sanity_checks_passed=false
    else
        echo "  [PASS] Found exactly $actual_gvcf_count gVCF files."
    fi

    # 2. If count is correct, check for empty files
    if [ "$sanity_checks_passed" = true ]; then
        echo "[CHECK 2] Verifying gVCF file sizes in $part_name..."
        empty_files_count=$(find "$chunk_dir_path" -maxdepth 1 -type f -name "*.g.vcf.gz" -size 0 | wc -l)
        if [ "$empty_files_count" -ne 0 ]; then
            echo "  [FAIL] Found $empty_files_count empty gVCF files."
            sanity_checks_passed=false
        else
            echo "  [PASS] All $actual_gvcf_count gVCF files are non-empty."
        fi
    fi
    
    # 3. Check for the source interval list file
    source_interval_file="${INTERVALS_SOURCE_DIR}/${part_name}.interval_list"
    if [ ! -f "$source_interval_file" ]; then
        echo "[CHECK 3] Verifying source interval file..."
        echo "  [FAIL] Source interval file not found at: $source_interval_file"
        sanity_checks_passed=false
    else
        echo "[CHECK 3] Verified source interval file exists."
    fi

    # --- EXECUTION ---
    if [ "$sanity_checks_passed" = true ]; then
        echo "[STATUS] All sanity checks passed for $part_name. Proceeding with job preparation."
        
        # ... [Tasks 1, 2, 3 for indexing, sample map, and interval list remain the same] ...
        echo "  -> Task 1: Indexing gVCF.gz files with tabix..."
        ( cd "$chunk_dir_path" || exit 1; find . -maxdepth 1 -type f -name "*.g.vcf.gz" | while read -r gvcf_file; do if [[ ! -f "${gvcf_file}.tbi" ]] || [[ "$gvcf_file" -nt "${gvcf_file}.tbi" ]]; then echo "     Indexing $gvcf_file..."; tabix -p vcf "$gvcf_file"; fi; done )
        echo "  -> Task 1: Indexing complete."

        echo "  -> Task 2: Generating sample map..."
        sample_map_path="${chunk_dir_path}/sample.map"
        ( cd "$chunk_dir_path" || exit 1; find . -maxdepth 1 -name "*.g.vcf.gz" | while read -r i; do sample_name=$(bcftools query -l "$i"); absolute_path_vcf=$(realpath "$i"); echo -e "${sample_name}\t${absolute_path_vcf}"; done > sample.map )
        echo "  -> Task 2: sample.map created at $sample_map_path"

        echo "  -> Task 3: Converting interval list format..."
        gatk_interval_file_path="${chunk_dir_path}/gatk_interval.list"
        awk '{print $1":"$2"-"$3}' "$source_interval_file" > "$gatk_interval_file_path"
        echo "  -> Task 3: GATK-formatted interval list created at $gatk_interval_file_path"

        # --- MODIFIED: Task 4 now includes partition selection ---
        # Select a partition in a round-robin fashion
        num_partitions=${#PARTITIONS[@]}
        partition_index=$((job_counter % num_partitions))
        selected_partition=${PARTITIONS[$partition_index]}

        echo "  -> Task 4: Generating dbimport.sh script for partition '$selected_partition'..."
        dbimport_script_path="${chunk_dir_path}/dbimport.sh"
        
        cat << EOF > "$dbimport_script_path"
#!/bin/bash
#SBATCH --job-name=${part_name}_dbimport
#SBATCH --output=${part_name}.out
#SBATCH --error=${part_name}.err
#SBATCH --partition=${selected_partition}
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=26
#SBATCH --mem=180G
#SBATCH --exclusive

echo "--- Starting GATK GenomicsDBImport for ${part_name} on partition ${selected_partition} at \$(date) ---"
# ... [rest of the generated script is the same] ...
module load gatk/4.4.0.0
WORKSPACE_PATH="${part_name}_Database"
SAMPLE_MAP="sample.map"
INTERVAL_FILE="gatk_interval.list"
TEMP_DIR="temp_dir"
mkdir -p "\$TEMP_DIR"
gatk --java-options "-Xmx110g -XX:ParallelGCThreads=26" \\
    GenomicsDBImport \\
    --genomicsdb-workspace-path "\$WORKSPACE_PATH" --batch-size ${EXPECTED_GVCF_COUNT} -L "\$INTERVAL_FILE" \\
    --bypass-feature-reader true --sample-name-map "\$SAMPLE_MAP" --tmp-dir "\$TEMP_DIR" \\
    --max-num-intervals-to-import-in-parallel 20 --reader-threads 26
if [ \$? -eq 0 ]; then echo "--- GATK GenomicsDBImport for ${part_name} COMPLETED successfully at \$(date) ---"; else echo "--- GATK GenomicsDBImport for ${part_name} FAILED at \$(date) ---"; exit 1; fi
EOF

        chmod +x "$dbimport_script_path"
        echo "  -> Task 4: Script created at $dbimport_script_path"

        # ... [Task 5, job throttling, is the same] ...
        echo "  -> Task 5: Checking for available SLURM slot..."
        while true; do current_jobs=$(squeue -u "$USERNAME" -h -t R,PD | wc -l); if [ "$current_jobs" -lt "$MAX_CONCURRENT_JOBS" ]; then echo "     Slot available ($current_jobs/$MAX_CONCURRENT_JOBS). Proceeding."; break; else echo "     Job limit reached ($current_jobs/$MAX_CONCURRENT_JOBS). Waiting for $SLEEP_INTERVAL seconds..."; sleep "$SLEEP_INTERVAL"; fi; done

        # Task 6: Submit the job
        echo "  -> Task 6: Submitting job for $part_name."
        (cd "$chunk_dir_path" && sbatch dbimport.sh)

        # MODIFIED: Increment the counter for the next job's partition
        job_counter=$((job_counter + 1))

    else
        echo "[STATUS] Sanity checks failed. Skipping all tasks for $part_name."
    fi
    echo "---------------------------------------------------------------------"
done
