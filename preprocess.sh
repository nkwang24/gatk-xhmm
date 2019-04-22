#!/bin/bash

# Set data location
DATA_DIR=<data_path>
# Set output location
RUN=output_folder_name
DIR=<output_path>/$RUN
mkdir $DIR
# Get list of all gzipped FASTQ files in data directory recursively
FLIST=$DIR/$RUN.fastq.list
find $DATA_DIR -name '*fastq.gz' > $FLIST

# Loop through pairs of FASTQ files for preprocessing
cat $FLIST |
while read -r F1; do
read -r F2

# Set sample ID using FASTQ file name
ID="${F1##*/}"
ID="${ID:0:7}.$RUN"

# Extract read group label from FASTQ header
HEAD=$(zless $F1 | head -1)
IFS=':' read -r -a array <<< $HEAD
RG="${array[2]}:${array[3]}:${array[9]}"

# If piped bam file doesn't exist
if [ ! -f $DIR/$ID.piped.bam ]; then
# Unmapped BAM from FASTQ
# https://gatkforums.broadinstitute.org/gatk/discussion/6484#latest
gatk --java-options "-Xmx8G" FastqToSam \
-F1 $F1 \
-F2 $F2 \
-O $DIR/$ID.unmapped.bam \
-RG $RG \
-SM $ID \
-LB VP

# Align with BWA-MEM and merge with uBAM to generate analysis ready BAM file
# https://gatkforums.broadinstitute.org/gatk/discussion/6483/how-to-map-and-clean-up-short-read-sequence-data-efficiently#step1
gatk --java-options "-Xmx8G" SamToFastq \
-I $DIR/$ID.unmapped.bam \
-F /dev/stdout \
--INTERLEAVE true --NON_PF true | \
/bwa-0.7.17/bwa mem -M -t 16 -p <path_to_fasta_reference> /dev/stdin | \
gatk --java-options "-Xmx8G" MergeBamAlignment \
-ALIGNED /dev/stdin \
-UNMAPPED $DIR/$ID.unmapped.bam \
-O $DIR/$ID.piped.bam \
-R <path_to_fasta_reference> -CREATE_INDEX true -ADD_MATE_CIGAR true \
-CLIP_ADAPTERS false -CLIP_OVERLAPPING_READS true \
-INCLUDE_SECONDARY_ALIGNMENTS true -MAX_INSERTIONS_OR_DELETIONS -1 \
-PRIMARY_ALIGNMENT_STRATEGY MostDistant -ATTRIBUTES_TO_RETAIN XS
fi

done

# Make BAM list for DepthOfCoverage
mkdir $DIR/xhmm
ls $DIR/*piped.bam > $DIR/xhmm/$RUN.bam.list

# Run DepthOfCoverage on all samples using GATK 3.8 (deprecated in 4.0)
# https://software.broadinstitute.org/gatk/documentation/tooldocs/3.8-0/org_broadinstitute_gatk_tools_walkers_coverage_DepthOfCoverage.php
# -L <path to interval list>
# -R <path to reference>
java -Xmx8G -jar /gatk/gatk3.8.jar \
-T DepthOfCoverage \
-I $DIR/xhmm/$RUN.bam.list \
-L <path_to_target_interval_list> \
-R <path_to_fasta_reference> \
-dt BY_SAMPLE -dcov 5000 -l INFO --omitDepthOutputAtEachBase --omitLocusTable \
--minBaseQuality 0 --minMappingQuality 20 --start 1 --stop 5000 --nBins 200 \
--includeRefNSites \
--countType COUNT_FRAGMENTS \
-o $DIR/xhmm/$RUN