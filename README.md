Optimized GATK Joint Calling (Divide & Conquer Approach)
Overview
This repository contains a joint genotyping pipeline using GATK, optimized for large-scale Whole Genome Sequencing (WGS) projects.
Instead of running GenomicsDBImport and GenotypeGVCFs on entire chromosomes, the genome is split into smaller interval chunks. Each chunk is processed independently and in parallel on an HPC cluster using SLURM.
The goal is simple: reduce total wall-clock time without changing the core GATK workflow.
For example, for ~200 WGS samples:
Standard joint calling can take ~25–27 days
Using this approach, it can be completed in ~3–4 days
Actual runtime depends on HPC configuration and job limits
Nothing in GATK best practices is modified. Only the way it is parallelized is different.
Why This Approach?
As sample size increases, GenomicsDBImport and GenotypeGVCFs become major bottlenecks.
Instead of processing full chromosomes:
Chromosomes are divided into 2 or 4 parts
Each part is handled independently
Jobs are distributed across available nodes
Final VCFs are merged
This makes joint calling practical for large cohorts.
Tools Required
GATK (v4.4+ recommended)
bcftools
tabix
SLURM scheduler
GNU Parallel (if used in JC step)
Input Requirements
You need:
Reference genome (.fasta)
Reference index (.fasta.fai)
Per-sample gVCFs (*.g.vcf.gz)
sample_names.txt (one sample ID per line)
A SLURM-based HPC cluster
Directory structure before running should look something like:
project/
│
├── gvcfs/
├── intervals/           (created in step 1)
├── split_gvcfs/         (created in step 2)
├── sample_names.txt
└── reference.fasta
Pipeline Steps
The pipeline consists of five scripts, executed in order.
01_generate_intervals.sh
Generates interval chunks from the reference .fai file.
Large chromosomes → split into 4 parts
Medium chromosomes → split into 2 parts
Others → kept as single region
Output:
intervals/
Run:
sbatch 01_generate_intervals.sh
Modify inside script:
Path to .fai file
SLURM resource settings if needed
02_prepare_region_directories.sh
Creates region-specific directories under split_gvcfs/.
Each interval gets its own folder.
Output:
split_gvcfs/chr1_part1/
split_gvcfs/chr1_part2/
...
Run:
sbatch 02_prepare_region_directories.sh
03_split_gvcfs_by_interval.sh
Splits each sample gVCF into region-specific gVCFs using bcftools view -R.
For every sample and every interval:
Extracts region-specific variants
Writes to corresponding folder
Output:
split_gvcfs/chr1_part1/sample_chr1_part1.g.vcf.gz
Run:
sbatch 03_split_gvcfs_by_interval.sh
Modify inside script:
GVCF_DIR
INTERVALS_DIR
OUTPUT_BASE
SAMPLE_LIST
04_run_genomicsdbimport.sh
Runs GenomicsDBImport region-wise.
For each interval:
Performs sanity checks
Indexes gVCFs if needed
Creates sample.map
Converts interval format
Submits GenomicsDBImport job
Output:
split_gvcfs/chr1_part1/chr1_part1_Database/
Run:
sbatch 04_run_genomicsdbimport.sh
Modify inside script:
EXPECTED_SAMPLE_COUNT
SLURM partition
Memory and CPU settings
05_run_joint_genotyping.sh
Runs GenotypeGVCFs for each interval-specific GenomicsDB.
Produces region-wise VCF files.
These VCFs can later be merged using:
bcftools concat
Run:
sbatch 05_run_joint_genotyping.sh
Modify:
Reference genome path
Database paths
Output directory
Resource settings
Performance Notes
This approach works well for:
100–1000 WGS samples
High-memory HPC clusters
Environments allowing multiple parallel jobs
For ~200 WGS samples:
Method	Approximate Runtime
Standard GATK Joint Calling	25–27 days
This Parallelized Approach	3–4 days
Actual runtime depends on:
Number of nodes available
Memory per job
Maximum concurrent jobs allowed per user
Important Notes
Ensure sufficient storage for split gVCFs and GenomicsDB workspaces
Monitor SLURM queue limits
Adjust memory settings according to cluster policy
Always verify final merged VCF integrity
This pipeline was developed to make large-cohort joint calling feasible and practical on SLURM-based HPC systems.
