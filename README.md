Overview
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
