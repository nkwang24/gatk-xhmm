# gatk-xhmm

Sample GATK-XHMM pipeline for use with bwa-0.7.17 / gatk-3.8 / gatk-4.0.9.0 / xhmm-1.0.  
Docker container found at https://hub.docker.com/r/nkwang24/gatk-xhmm

**_preprocess.sh_** uses GATK best practices to generate BAM files from a batch of FASTQ files and runs the batch through GATK's DepthOfCoverage to arrive at the input for XHMM.

**_xhmm.sh_** combines the outputs from multiple batches of preprocess.sh and runs the XHMM CNV calling pipeline (http://atgu.mgh.harvard.edu/xhmm/tutorial.shtml).
