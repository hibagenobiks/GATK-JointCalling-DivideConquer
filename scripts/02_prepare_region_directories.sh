#!/bin/bash

#SBATCH --output=split_big.%J.out
#SBATCH --error=split_big.%J.err

#

#SBATCH --exclusive
#SBATCH --job-name=split_big
#SBATCH --partition=cbr_q_t
#SBATCH --ntasks-per-node=72
#SBATCH --mem-per-cpu=180G
#SBATCH -N 1
et -euo pipefail

FAI="/gpfs/data/user/shweta_lab/data/SKAN/resources/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.fai"
OUTDIR="intervals"
mkdir -p "$OUTDIR"

# Chromosomes to split into 4 parts
split_4=(chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10)
# Chromosomes to split into 2 parts
split_2=(chr11 chr12 chr13 chr14 chr15 chr16 chr17 chr18 chr19 chr20 chr21 chr22 chrX chrY chrM)

while read -r chr size _; do
  # Skip unrecognized chromosomes
  if [[ ! "$chr" =~ ^chr[0-9XYM]+$ ]]; then
    continue
  fi

  # Split into 4 chunks
  if [[ " ${split_4[*]} " =~ " $chr " ]]; then
    chunk=$((size / 4))
    for i in {1..4}; do
      start=$(( (i - 1) * chunk + 1 ))
      end=$(( i * chunk ))
      # Adjust last chunk end to size (in case of rounding)
      if [[ $i -eq 4 ]]; then end=$size; fi
      echo -e "$chr\t$start\t$end" > "$OUTDIR/${chr}_part${i}.interval_list"
    done

  # Split into 2 chunks
  elif [[ " ${split_2[*]} " =~ " $chr " ]]; then
    half=$((size / 2))
    echo -e "$chr\t1\t$half" > "$OUTDIR/${chr}_part1.interval_list"
    echo -e "$chr\t$((half + 1))\t$size" > "$OUTDIR/${chr}_part2.interval_list"

  # Else, treat whole chromosome as single region
  else
    echo -e "$chr\t1\t$size" > "$OUTDIR/${chr}.interval_list"
  fi
done < "$FAI"

echo "All intervals created in $OUTDIR/"
(base) [1086][hiba@cbrhpc1:/gpfs/data/user/shweta_lab/data/SKAN/analyses/Scripts/Joint_callng/parralel_JC]$ cat creatingdirectory.sh 
#!/bin/bash

set -euo pipefail

# Path to your interval files
INTERVALS_DIR="/gpfs/data/user/shweta_lab/data/SKAN/analyses/Scripts/Joint_callng/parralel_JC/intervals"

# Final output base directory
OUTPUT_DIR="/gpfs/data/user/shweta_lab/data/SKAN/analyses/Scripts/Joint_callng/parralel_JC/split_gvcfs"

# Create the base output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Loop through each interval file and make a directory
for interval_file in "$INTERVALS_DIR"/*.interval_list; do
    interval_name=$(basename "$interval_file" .interval_list)
    mkdir -p "$OUTPUT_DIR/$interval_name"
    echo "Created: $OUTPUT_DIR/$interval_name"
done

echo "All region directories created."
