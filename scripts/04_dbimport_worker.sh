#!/bin/bash

#SBATCH --output=dbimport.%J.out
#SBATCH --error=dbimport.%J.err

#

#SBATCH --job-name=dbimport
#SBATCH --partition=cbr_q_t
#SBATCH --ntasks-per-node=72
#SBATCH --mem-per-cpu=180G
#SBATCH  -N 1
#SBATCH --exclusive

gatk --java-options "-Xmx110g -XX:ParallelGCThreads=64" \
       GenomicsDBImport \
       --genomicsdb-workspace-path /gpfs/data/user/shweta_lab/data/ATPARK/data/vcfs/gvcfs/96Database \
       --batch-size 96 \
       -L intervals.list \
       --bypass-feature-reader true \
       --sample-name-map cohort.sample_map \
       --tmp-dir /gpfs/data/user/shweta_lab/data/ATPARK/data/vcfs/gvcfs/temp_dir \
       --max-num-intervals-to-import-in-parallel 25 \
       --reader-threads 26
