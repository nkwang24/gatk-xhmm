#!/bin/bash

# https://atgu.mgh.harvard.edu/xhmm/tutorial.shtml
# Menachem Fromer, Jennifer L. Moran, Kimberly Chambert, Eric Banks, Sarah E. Bergen,
# Douglas M. Ruderfer, Robert E. Handsaker, Steven A. McCarroll, Michael C. O'Donovan,
# Michael J. Owen, George Kirov, Patrick F. Sullivan, Christina M. Hultman, Pamela Sklar,
# and Shaun M. Purcell. Discovery and statistical genotyping of copy-number variation
# from whole-exome sequencing depth. American Journal of Human Genetics, 91:597-607, Oct 2012.

# Get list of sample_interval_summary files from multiple DepthOfCoverage runs
cd <path_to_preprocess_output>
find . -name *.sample_interval_summary > ./sample_interval_summary.list

# Combine DepthOfCoverage outputs
/statgen-xhmm-cc14e528d909/xhmm --mergeGATKdepths -o DATA.txt \
--GATKdepthsList sample_interval_summary.list

# Filter and mean-center targets
# --excludeSamples (optional) List of samples to exclude, e.g. samples with %_bases_above_15 < 98%
# --minTargetSize --minMeanTargetRD --minMeanSampleRD Filter parameters based on panel metrics
/statgen-xhmm-cc14e528d909/xhmm --matrix -r ./DATA.txt --centerData --centerType target \
-o ./DATA.filtered_centered.txt \
--outputExcludedTargets ./DATA.filtered_targets.txt \
--outputExcludedSamples ./DATA.filtered_samples.txt \
--excludeSamples ./low_quality_samples.txt \
--minTargetSize 10 \
--minMeanTargetRD 50 \
--minMeanSampleRD 350

# Runs PCA on mean-centered data
/statgen-xhmm-cc14e528d909/xhmm --PCA -r ./DATA.filtered_centered.txt --PCAfiles ./DATA.PCA

# Normalizes mean-centered data using PCA information
/statgen-xhmm-cc14e528d909/xhmm --normalize -r ./DATA.filtered_centered.txt --PCAfiles ./DATA.PCA \
--normalizeOutput ./DATA.PCA_normalized.txt \
--PCnormalizeMethod PVE_mean --PVE_mean_factor 0.7

# Filters and z-score centers (by sample) the PCA-normalized data
# --maxSdTargetRD --maxSdSampleRD Filter parameters based on data
/statgen-xhmm-cc14e528d909/xhmm --matrix -r ./DATA.PCA_normalized.txt --centerData --centerType sample --zScoreData \
-o ./DATA.PCA_normalized.filtered.sample_zscores.txt \
--outputExcludedTargets ./DATA.PCA_normalized.filtered_targets.txt \
--outputExcludedSamples ./DATA.PCA_normalized.filtered_samples.txt \
--maxSdTargetRD 100 \
--maxSdSampleRD 60

# Filters original read-depth data to be the same as filtered, normalized data
/statgen-xhmm-cc14e528d909/xhmm --matrix -r ./DATA.txt \
--excludeTargets ./DATA.filtered_targets.txt \
--excludeTargets ./DATA.PCA_normalized.filtered_targets.txt \
--excludeSamples ./DATA.filtered_samples.txt \
--excludeSamples ./DATA.PCA_normalized.filtered_samples.txt \
--excludeSamples ./low_quality_samples.txt \
-o ./DATA.same_filtered.txt

# Discovers CNVs in normalized data
# -p <path to params.txt file>
/statgen-xhmm-cc14e528d909/xhmm --discover -p <path_to_params.txt> \
-r ./DATA.PCA_normalized.filtered.sample_zscores.txt -R ./DATA.same_filtered.txt \
-c ./DATA.xcnv -a ./DATA.aux_xcnv -s ./DATA

# Genotypes discovered CNVs in all samples
# /statgen-xhmm-cc14e528d909/xhmm --genotype -p <path_to_params.txt> \
# -r ./DATA.PCA_normalized.filtered.sample_zscores.txt -R ./DATA.same_filtered.txt \
# -g ./DATA.xcnv -F <path_to_fasta_reference> \
# -v ./DATA.vcf
