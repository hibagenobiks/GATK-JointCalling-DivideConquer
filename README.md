# Overview
This workflow implements an **accelerated joint genotyping pipeline** using `GATK`, built around a **divide and conquer strategy** for efficient large-scale variant calling.  
It intelligently partitions the genomic space into manageable regions, enabling **massively parallel processing** on HPC clusters with `SLURM` and GNU `parallel`.

By splitting GVCFs according to genomic intervals and running `GenomicsDBImport` and `GenotypeGVCFs` steps in parallel, the pipeline **significantly speeds up** the standard GATK joint genotyping process — without compromising accuracy.

This approach is ideal for projects involving **hundreds to thousands of samples**, optimizing resource utilization (CPU cores, memory) and reducing wall-clock time substantially.

# Key Features

- **Divide and Conquer Partitioning**:  
    Large chromosomes are divided into multiple chunks for balanced processing.
    
- **Parallelized Processing**:  
    GenomicsDBImport and GenotypeGVCFs are executed simultaneously across intervals.
    
- **HPC-Optimized**:  
    Designed for SLURM-based clusters, fully leveraging multi-core, high-memory environments.
    
- **Full Compatibility with GATK Best Practices**:  
    Maintains the standard GATK workflows, ensuring downstream compatibility.
    
- **Scalable**:  
    Easily adaptable to projects with different sample sizes or resource configurations.
    

---

# Tools Used

- **GATK** (Genome Analysis Toolkit)
    
- **BCFtools** (for VCF processing)
    
- **GNU Parallel** (for job parallelization)
    
- **SLURM** (HPC job scheduling)
    

---

# Why Use This Pipeline?

When dealing with **large cohorts of samples**, standard GATK joint calling becomes **extremely slow and computationally expensive**.  
As the number of samples grows, the runtime and memory demands of `GenomicsDBImport` and `GenotypeGVCFs` can become bottlenecks.

This pipeline addresses the challenge by implementing a **Divide and Conquer strategy**:

- **Divide**: The genome and GVCF inputs are intelligently partitioned into smaller, manageable regions.
    
- **Conquer**: These regions are processed **in parallel**, dramatically accelerating joint genotyping without compromising accuracy.
    
 By adopting this approach, **joint calling becomes scalable and feasible** for **hundreds to thousands** of samples on HPC clusters.
---

Actual runtime depends on cluster configuration and job limits.

---
## Input

Required inputs:

- Reference genome (`reference.fasta`)
- Reference index (`reference.fasta.fai`)
- Per-sample gVCFs (`*.g.vcf.gz`)
- `sample_names.txt` (one sample ID per line)

Example structure before running:

project/  
├── gvcfs/  
├── reference.fasta  
├── reference.fasta.fai  
└── sample_names.txt

---  
  
## Pipeline Steps  
  
Run the scripts in order.  
  
### 1. Generate interval chunks  
  
`01_generate_intervals.sh`  
  
Creates genomic interval partitions from the `.fai` file.  
  
- chr1–chr10 → split into 4 parts    
- chr11–chr22, chrX/Y/M → split into 2 parts    
  
Run:  

```
sbatch 01_generate_intervals.sh
```
  
Output:  

intervals/

  
---  
  
### 2. Prepare region directories  
  
`02_prepare_region_directories.sh`  
  
Creates region-specific directories under `split_gvcfs/`.  
  
Run:  

`sbatch 02_prepare_region_directories.sh`

---  
  
### 3. Split gVCFs by interval  
  
`03_split_gvcfs_by_interval.sh`  
  
For each sample and each interval:  
  
- Extract region-specific records  
- Write interval-level gVCFs  
  
Run:  

```
sbatch 03_split_gvcfs_by_interval.sh
```
  
Before running, update inside the script:  
  
- `GVCF_DIR`  
- `INTERVALS_DIR`  
- `OUTPUT_BASE`  
- `SAMPLE_LIST`  
  
Output example:  

split_gvcfs/chr1_part1/sample_chr1_part1.g.vcf.gz

---  
  
### 4. Run GenomicsDBImport per interval  
  
`04_run_genomicsdbimport.sh`  
  
For each interval:  
  
- Validates gVCF counts  
- Indexes gVCFs if required  
- Creates `sample.map`  
- Submits GenomicsDBImport job  
  
Run:  

```
sbatch 04_run_genomicsdbimport.sh
```

Modify:  
  
- `EXPECTED_SAMPLE_COUNT`  
- SLURM resource settings  
- Partition name  
  
Output example:  

split_gvcfs/chr1_part1/chr1_part1_Database/

---  
### 5. Run joint genotyping  
  
`05_run_joint_genotyping.sh`  
  
Runs GenotypeGVCFs per interval database.  
  
Run:  

sbatch 05_run_joint_genotyping.sh
  
After completion, region-wise VCFs can be merged using bcftools concat

---  
## Performance  
  
Approximate benchmark for ~200 WGS samples:
  
| Method                         | Runtime    |
| ------------------------------ | ---------- |
| Standard WGS JC                | 25–27 days |
| Interval-parallelized approach | 3–4 days   |
  
Performance depends on:  
  
- Number of available nodes    
- Memory per job    
- Maximum concurrent jobs allowed    
  
---  
  
## Notes  
  
- Ensure adequate storage for intermediate gVCFs and GenomicsDB workspaces    
- Monitor SLURM queue limits    
- Adjust memory and CPU settings based on cluster policy    
- Validate final merged VCF before downstream analysis    
  
This pipeline was developed to make large-cohort joint calling feasible on SLURM-based HPC systems while maintaining standard GATK practices.
