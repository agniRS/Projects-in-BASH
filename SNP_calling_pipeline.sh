#!/bin/bash

#input statements

reads1=/home/a/Downloads/testread1.fq
reads2=/home/a/Downloads/testread2.fq
ref=/home/a/Downloads/chr17.fa
realign=1
output=asinha342
millsFile=/home/a/Downloads/resources_broad_hg38_v0_Mills_and_1000G_gold_standard.indels.hg38.vcf
gunzip=1
verbose=1
index=1
usageinfo=0
while getopts "a:b:r:e:o:f:z:v:i:h:w" option
do
	case $option in
	a) reads1=$OPTARG;;
	b) reads2=$OPTARG;;
	r) ref=$OPTARG;;
	e) realign=$OPTARG;;
	o) output=$OPTARG;;
	f) millsFile=$OPTARG;;
	z) gunzip=$OPTARG;;
	v) verbose=$OPTARG;;
	i) index=$OPTARG;;
	h) usageinfo=$OPTARG;;
	w) answer=y;
esac    done
#manual mode:
if [[ $usageinfo -eq 1 ]];
then
	echo "Option
Meaning
-a
Input reads file – pair 1
-b
Input reads file – pair 2
-r
Reference genome file
-e
Perform read re-alignment
-o
Output VCF file name
-f
Mills file location
-z
Output VCF file should be gunzipped (*.vcf.gz)
-v
Verbose mode; print each instruction/command to tell the user what your script is doing right now
-i
Index your output BAM file (using samtools index)
-h
Print usage information (how to run your script and the arguments it takes in) and exit
getopts?
"
exit
fi
#checks for read1 read2 and reference genome
if [[ $verbose -eq 1 ]];
then
	echo "checks if all input files exist"
fi

if test -f "$reads1";
then
        true
else
        echo " $reads1 does not exist"
        exit
fi
if test -f "$reads2";
then
        true
else
        echo " $reads2 does not exist"
        exit
fi
if test -f "$ref";
then
        true
else
        echo " $ref does not exist"
        exit
fi

if test -f "$output.vz"
then
        echo " $output.vz already exists. DO you want to overwrite ?(Y/N)"
        read $answer
	if [[ $answer -eq "N" || $answer -eq "n" ]];
	then
		exit
	else
		true
	fi
else true		
fi
#now we start XD
if [[ $verbose -eq 1 ]];
then
	echo "Pipeline starts"
	echo " Now bwa(Burrows Wheeler Aligner) is used to index the reference genome file"
	echo "bwa index $ref"
fi
#use bawa to index the reference genome file
bwa index $ref
if [[ $verbose -eq 1 ]];
then
        echo "reference genome file has been indexed"
        echo " Now bwa mem  is used to map the given reads to the given reference genome "
	echo "bwa mem -R '@RG\tID:foo\tSM:bar\tLB:library1' $ref $reads1 $reads2 > mappedreads.sam"

fi
#now we map the reads to the reference using bwa again
bwa mem -R '@RG\tID:foo\tSM:bar\tLB:library1' $ref $reads1 $reads2 > mappedreads.sam
if [[ $verbose -eq 1 ]];
then
        echo "Mapped reads file is generated in .sam format"
        echo " Because BWA can sometimes leave unusual FLAG information on SAM records, the file will now  clean up read pairing information and flags"
	echo "samtools fixmate -O bam mappedreads.sam clnmappedreads.ba"
fi

#samtools fixmate -O bam mappedreads.sam fxdmappedreads.bam
samtools fixmate -O bam mappedreads.sam clnmappedreads.bam
if [[ $verbose -eq 1 ]];
then
        echo "Mapped reads file has been cleaned and a new cleaned mappedreads.bam  file has been generated "
	echo "Converting this file from .bam to .sam to help in sorting(next step)"
	echo "samtools view -h clnmappedreads.bam > clnmappedreads.sam
"
fi
#convt bam to sam again
samtools view -h clnmappedreads.bam > clnmappedreads.sam
if [[ $verbose -eq 1 ]];
then
        echo "Cleaned mapperd reads file has been converted  from .bam to .sam"
        echo "Now we sort the file  from name order to coordinate order using samtools "
	echo "samtools sort -O bam -o sortedclnmappedreads.bam -T /tmp/lane_temp clnmappedreads.sam"
fi 
#now we sort them from name order to coordinate order
samtools sort -O bam -o sortedclnmappedreads.bam -T /tmp/lane_temp clnmappedreads.sam
if [[ $verbose -eq 1 ]];
then
        echo "Now we generate index files for the reference file im order for realignment "
        echo "samtools faidx $ref"
fi
samtools faidx $ref
if [[ $verbose -eq 1 ]];
then
        echo "samtools dict $ref"
fi
samtools dict $ref
if [[ $realign -eq 1 ]];
then
	true
else 
	exit
fi
if [[ $verbose -eq 1 ]];
then
        echo "In order to reduce the number of miscalls of INDELs in the data  the raw gapped alignmentis realigned  with the Broad’s GATK Realigner "
	echo "samtools index lane_sorted.bam (to create a bam index file)"
	echo "java -Xmx2g -jar $HOME/bin/GenomeAnalysisTK.jar -T RealignerTargetCreator -R $ref -I sortedclnmappedreads.bam --known $millsFile -o lane.intervals"
fi  

samtools index lane_sorted.bam

java -Xmx2g -jar $HOME/bin/GenomeAnalysisTK.jar -T RealignerTargetCreator -R $ref -I sortedclnmappedreads.bam --known $millsFile -o lane.intervals
if [[ $verbose -eq 1 ]];
then
        echo "Lane intervals file was created, this will be used  to generate the realignment file "
        echo "java -Xmx4g -jar $HOME/bin/GenomeAnalysisTK.jar -T IndelRealigner -R $ref -I sortedclnmappedreads.bam -targetIntervals lane.intervals -o lane_realigned.bam --unsafe
 "
fi
java -Xmx4g -jar $HOME/bin/GenomeAnalysisTK.jar -T IndelRealigner -R $ref -I sortedclnmappedreads.bam -targetIntervals lane.intervals -o lane_realigned.bam --unsafe
if [[ $verbose -eq 1 ]];
then
        echo "Realigned mapped reads file generated." 
fi
if [[ $index -eq 0 ]];
then
	exit
else true
fi
if [[ $verbose -eq 1 ]];
then
	echo"Now we index the file "
        echo "samtools index lane_realigned.bam "
fi
samtools index lane_realigned.bam
#vcf file creation
if [[ $verbose -eq 1 ]];
then
	echo "Now we convert the previous.bam file into a .vz.gz ( a file with genomic positions) using bcftools "
        echo " bcftools mpileup -Ou -f $ref lane_realigned.bam| bcftools call -vmO z -o studynew.vcf.gz
"
fi 
bcftools mpileup -Ou -f $ref lane_realigned.bam| bcftools call -vmO z -o $output.vcf.gz
if [[ $verbose -eq 1 ]];
then
        echo ".vcf file created "
        echo " gunzip $output.vcf.gz"
fi
if [[ $gunzip -eq 0 ]];
then
	exit
else true
fi

if [[ $verbose -eq 1 ]];
then
        echo "extracting $output.vcf.gz realigned file "
        echo " gunzip $output.vcf.gz"
fi
gunzip $output.vcf.gz
#set answer to 1
answer=1
#VCF TO BED
if [[ $verbose -eq 1 ]];
then
        echo "Extraction complete. Now converting .vcf to .bed file "
        echo "sed '/^##/d' $output.vcf | sed s/'chr'//g | awk 'NR>1' | awk '{r=$5;a=$4;b=length($5);c=length($4);l=(c-b);stop=$2+l;print $1"\t"$2"\t"stop"\t"l}' >$output.bed"
fi

#creating the .bed file
sed '/^##/d' $output.vcf | sed s/'chr'//g | awk 'NR>1' | awk '{r=$5;a=$4;b=length($5);c=length($4);l=(c-b);stop=$2+l;print $1"\t"$2"\t"stop"\t"l}' >$output.bed

#.bed file created 
if [[ $verbose -eq 1 ]];
then
        echo " .bed file succesfully created.Generating indels.txt and .snps.tx file from this"
        echo "grep '-' outputfile.bed >indels5.txt
sed '/-/d' outputfile.bed >snps4.txt"
fi
#create snps.txt and indels.txt
grep '-' $output.bed >indels.txt
sed '/-/d' $output.bed >snps.txt

