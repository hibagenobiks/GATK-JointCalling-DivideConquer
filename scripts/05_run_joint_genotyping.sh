#!/bin/bash

# ##############################################################################
# ### GATK GenotypeGVCFs Pipeline Manager                                    ###
# ##############################################################################
#
# This script automates submitting joint-calling jobs with dynamic partition
# assignment. It runs quickly on the login node and exits.
#
# ##############################################################################


# --- 1. CONFIGURATION ---
echo "--- Initializing Configuration ---"

# --- Main Paths ---
REF="/gpfs/data/user/shweta_lab/data/SKAN/resources/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna"
BASE_DIR="/gpfs/data/user/shweta_lab/data/ATPARK/data/vcfs/gvcfs/split_gvcfs"
DB_PARENT_DIR="${BASE_DIR}"
OUT_DIR="${BASE_DIR}/output_genotyped/vcf"

# --- SBATCH Resource Defaults ---
DEFAULT_MEM="180G"
DEFAULT_CPUS_PER_TASK=18
# Array of partitions to cycle through for worker jobs
PARTITIONS=("cbr_q_large" "cbr_q_huge" "gpu")

# --- Create output directory if it doesn't exist ---
mkdir -p "$OUT_DIR"
echo "Output VCFs will be written to: $OUT_DIR"
echo "Jobs will be distributed across partitions: ${PARTITIONS[*]}"
echo "--- Configuration Complete ---"


# --- 2. HELPER FUNCTION ---
# This function generates and submits a SLURM script.
# Arguments:
#   $1: Job Name
#   $2: Number of parallel tasks
#   $3: The selected SLURM partition for this job
#   $4: An array of parts to process
# ##############################################################################
generate_and_submit() {
    local job_name=$1
    local ntasks=$2
    local selected_partition=$3
    local parts_array=("${@:4}")

    local parts_string="${parts_array[*]}"
    local script_filename="temp_sbatch_${job_name}.sh"

    echo "-------------------------------------------------------------"
    echo "Generating script for: $job_name"
    echo "  - Target Partition:      $selected_partition"
    echo "  - Parallel Tasks (-j):   $ntasks"
    echo "  - Parts to process:      $parts_string"

    cat << 'EOF' > "$script_filename"
#!/bin/bash
#SBATCH --output=%x.%J.out
#SBATCH --error=%x.%J.err
#SBATCH --job-name=${job_name}
#SBATCH --partition=${selected_partition}
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=${ntasks}
#SBATCH --cpus-per-task=${DEFAULT_CPUS_PER_TASK}
#SBATCH --mem=${DEFAULT_MEM}
#SBATCH --exclusive

echo "========================================================"
echo "### Starting GATK GenotypeGVCFs"
echo "### Job Name:       ${job_name}"
echo "### Partition:      ${selected_partition}"
echo "### Start Time:     $(date)"
echo "========================================================"

# Load required modules
module load gatk/4.4.0.0
module load parallel

# --- Define Paths ---
export REF="${REF}"
export DB_PARENT_DIR="${DB_PARENT_DIR}"
export OUT_DIR="${OUT_DIR}"

# --- Define Parts ---
PARTS=(${parts_string})

# Run GenotypeGVCFs for each part in parallel
parallel -j ${ntasks} --verbose '
    echo "--- Processing part: {} ---"

    DB_PATH=${DB_PARENT_DIR}/{}/{}_Database
    INTERVAL_FILE=${DB_PARENT_DIR}/{}/gatk_interval.list
    OUT_VCF=${OUT_DIR}/{}.vcf.gz

    gatk --java-options "-Xmx32G -XX:ParallelGCThreads=16" GenotypeGVCFs \
      -R ${REF} \
      -V "gendb://${DB_PATH}" \
      -L "${INTERVAL_FILE}" \
      -O "${OUT_VCF}"
' ::: "${PARTS[@]}"

echo "========================================================"
echo "### Job ${job_name} Finished"
echo "### End Time:       $(date)"
echo "========================================================"
EOF

    # Replace placeholders in the generated script with actual values
    sed -i "s|\${job_name}|${job_name}|g" "$script_filename"
    sed -i "s|\${ntasks}|${ntasks}|g" "$script_filename"
    sed -i "s|\${selected_partition}|${selected_partition}|g" "$script_filename"
    sed -i "s|\${DEFAULT_CPUS_PER_TASK}|${DEFAULT_CPUS_PER_TASK}|g" "$script_filename"
    sed -i "s|\${DEFAULT_MEM}|${DEFAULT_MEM}|g" "$script_filename"
    sed -i "s|\${REF}|${REF}|g" "$script_filename"
    sed -i "s|\${DB_PARENT_DIR}|${DB_PARENT_DIR}|g" "$script_filename"
    sed -i "s|\${OUT_DIR}|${OUT_DIR}|g" "$script_filename"
    sed -i "s|\${parts_string}|${parts_string}|g" "$script_filename"

    sbatch "$script_filename"
    rm "$script_filename"
}


# --- 3. JOB SUBMISSION LOGIC ---
echo -e "\n--- Starting Job Submission ---"

# Initialize a counter for cycling through partitions
job_counter=0
num_partitions=${#PARTITIONS[@]}

# --- Group 1: Chromosomes 1-10 ---
for i in {1..10}; do
    selected_partition=${PARTITIONS[$((job_counter % num_partitions))]}
    job_name="JC_chr${i}"
    ntasks=4
    parts=("chr${i}_part1" "chr${i}_part2" "chr${i}_part3" "chr${i}_part4")
    generate_and_submit "$job_name" "$ntasks" "$selected_partition" "${parts[@]}"
    job_counter=$((job_counter + 1))
done

# --- Group 2: Chromosomes 11-22 ---
for i in $(seq 11 2 21); do
    j=$((i + 1))
    selected_partition=${PARTITIONS[$((job_counter % num_partitions))]}
    job_name="JC_chr${i}_chr${j}"
    ntasks=4
    parts=("chr${i}_part1" "chr${i}_part2" "chr${j}_part1" "chr${j}_part2")
    generate_and_submit "$job_name" "$ntasks" "$selected_partition" "${parts[@]}"
    job_counter=$((job_counter + 1))
done

# --- Group 3: Sex Chromosomes and Mitochondria ---
selected_partition=${PARTITIONS[$((job_counter % num_partitions))]}
job_name="JC_chrX_chrY"
ntasks=4
parts=("chrX_part1" "chrX_part2" "chrY_part1" "chrY_part2")
generate_and_submit "$job_name" "$ntasks" "$selected_partition" "${parts[@]}"
job_counter=$((job_counter + 1))

selected_partition=${PARTITIONS[$((job_counter % num_partitions))]}
job_name="JC_chrM"
ntasks=2
parts=("chrM_part1" "chrM_part2")
generate_and_submit "$job_name" "$ntasks" "$selected_partition" "${parts[@]}"
job_counter=$((job_counter + 1))

echo "-------------------------------------------------------------"
echo -e "\n### All $job_counter joint-calling jobs have been submitted. ###"
echo "### This script will now exit. Monitor your queue with: squeue -u $(whoami) ###"
