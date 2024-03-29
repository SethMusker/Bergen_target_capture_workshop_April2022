#!/usr/bin/env nextflow

//////////////////////////////////////
//  Nextflow Pipeline for HybPiper  // 
//////////////////////////////////////

nextflow.enable.dsl=2

def helpMessage() {
    log.info """

    Usage:
    The typical command for running the pipeline is as follows:

    nextflow run hybpiper-rbgv-pipeline.nf \
    -c hybpiper-rbgv.config \
    --illumina_reads_directory <directory> \
    --target_file <fasta_file> \
    -profile <profile>

    Mandatory arguments:

      ############################################################################

      --illumina_reads_directory <directory>    
                                  Path to folder containing illumina read file(s)

      --target_file <file>        File containing fasta sequences of target genes

      #############################################################################

    Optional arguments:

      -profile <profile>          Configuration profile to use. Can use multiple 
                                  (comma separated). Available: standard (default), 
                                  slurm

      --namelist                  A text file containing sample names. Only these 
                                  samples will be processed, By default, all samples 
                                  in the provided <Illumina_reads_directory> 
                                  directory are processed

      --cleanup                   Run the HybPiper script 'cleanup.py' for each gene 
                                  directory after 'reads_first.py'

      --nosupercontigs            Do not create supercontigs. Use longest Exonerate 
                                  hit only. Default is off  

      --bbmap_subfilter <int>     Ban alignments with more than this many 
                                  substitutions when performing read-pair mapping to 
                                  supercontig reference (bbmap.sh). Default is 7

      --memory <int>              Memory (RAM) amount in GB to use for bbmap.sh with 
                                  'exonerate_hits.py'. Default is 1 GB

      --discordant_reads_edit_distance <int>    
                                  Minimum number of base differences between one read 
                                  of a read pair vs the supercontig reference for a 
                                  read pair to be flagged as discordant. Default is 5
      
      --discordant_reads_cutoff <int>           
                                  Minimum number of discordant reads pairs required 
                                  to flag a supercontigs as a potential chimera of 
                                  contigs from multiple paralogs. Default is 5

      --merged                    Merge forward and reverse reads, and run SPAdes 
                                  assembly with merged and unmerged (the latter 
                                  in interleaved format) data. Default is off

      --paired_and_single         Use when providing both paired-end R1 and R2 read 
                                  files as well as a file of single-end reads for each 
                                  sample       

      --single_end                Use when providing providing only a folder of 
                                  single-end reads 

      --outdir <directory_name>                 
                                  Specify the name of the pipeline results directory. 
                                  Default is 'results'                                 

      --read_pairs_pattern <pattern>            
                                  Provide a comma-separated read-pair pattern for 
                                  matching fowards and reverse paired-end readfiles, 
                                  e.g. '1P,2P'. Default is 'R1,R2'

      --single_pattern <pattern>                
                                  Provide a pattern for matching single-end read 
                                  files. Default is 'single'

      --use_blastx                Use a protein target file and map reads to targets 
                                  with BLASTx. Default is a nucleotide target file 
                                  and mapping of reads to targets using BWA

      --num_forks <int>           Specify the number of parallel processes (e.g. 
                                  concurrent runs of 'reads.first.py') to run at any 
                                  one time. Can be used to prevent Nextflow from using 
                                  all the threads/cpus on your machine. Default is 
                                  to use the maximum number possible      

      --cov_cutoff <int>          Coverage cutoff to pass to the SPAdes assembler. 
                                  Default is 8

      --blastx_evalue <value>     Evalue to pass to blastx when using blastx mapping, 
                                  i.e., when the --use_blastx or 
                                  --translate_target_file_for_blastx flag is specified. 
                                  Default is 1e-4

      --paralog_warning_min_len_percent <decimal> 
                                  Minimum length percentage of a SPAdes contig vs 
                                  reference protein query for a paralog warning to be 
                                  generated and a putative paralog contig to be 
                                  recovered. Default is 0.75 

      --translate_target_file_for_blastx        
                                  Translate a nucleotide target file. If set, the 
                                  --use_blastx is set by default. Default is off

      --use_trimmomatic           Trim forwards and reverse reads using Trimmomatic.
                                  Default is off

      --trimmomatic_leading_quality <int>       
                                  Cut bases off the start of a read, if below this 
                                  threshold quality.Default is 3

      --trimmomatic_trailing_quality <int>      
                                  Cut bases off the end of a read, if below this 
                                  threshold quality. Default is 3

      --trimmomatic_min_length <int>            
                                  Drop a read if it is below this specified length. 
                                  Default is 36

      --trimmomatic_sliding_window_size <int>   
                                  Size of the sliding window used by Trimmomatic; 
                                  specifies the number of bases to average across. 
                                  Default is 4

      --trimmomatic_sliding_window_quality <int>
                                  Specifies the average quality required within the 
                                  sliding window. Default is 20

      --run_intronerate           Run intronerate.py to recover (hopefully) intron 
                                  and supercontig sequences. Default is off, and so 
                                  fasta files in `subfolders 09_sequences_intron` and 
                                  `10_sequences_supercontig` will be empty

      --combine_read_files        Group and concatenate read-files via a common prefix. 
                                  Useful if samples have been run across multiple lanes. 
                                  Default prefix is all text preceding the first 
                                  underscore (_) in read filenames

      --combine_read_files_num_fields <int>     
                                  Number of fields (delimited by an underscore) to use 
                                  for combining read files when using the 
                                  `--combine_read_files` flag. Default is 1

    """.stripIndent()
}


/**
* @function printAllMethods
* @purpose Prints an objects class name and then list the associated class functions.
* From https://bateru.com/news/2011/11/code-of-the-day-groovy-print-all-methods-of-an-object/
**/
// Filename: printAllMethodsExample.groovy
void printAllMethods( obj ){
    if( !obj ){
    println( "Object is null\r\n" );
    return;
    }
  if( !obj.metaClass && obj.getClass() ){
        printAllMethods( obj.getClass() );
    return;
    }
  def str = "class ${obj.getClass().name} functions:\r\n";
  obj.metaClass.methods.name.unique().each{ 
    str += it+"(); "; 
  }
  println "${str}\r\n";
}

/* 
Include a few default params here to print useful help (if requested) or if minimal input is not provided.
*/
params.help = false
params.illumina_reads_directory = false
params.target_file = false

// Check that input directories are provided
if (params.help || !params.illumina_reads_directory || !params.target_file) {
  helpMessage()
  exit 0
}

// Check that paralog_warning_min_len_percent value is a decimal between 0 and 1
if (params.paralog_warning_min_len_percent < 0 || params.paralog_warning_min_len_percent >1) {
println("""
  The value for --paralog_warning_min_len_percent should be between 0 and 1. 
  Your value is ${params.paralog_warning_min_len_percent}""".stripIndent())
exit 0
}

// Check that non-overlapping options are provided
if (params.single_end && params.paired_and_single) {
  println('Please use --single_end OR --paired_and_single, not both!')
  exit 0
}

// Don't allow params.paired_and_single and params.use_trimmomatic
if (params.paired_and_single && params.use_trimmomatic) {
  println("""
    Trimmomatic can't be used with paired plus single reads yet - 
    let me know if this would be useful!""".stripIndent())
  exit 0
}

// Check for unrecognised pararmeters
allowed_params = ["cleanup", "nosupercontigs", "memory","discordant_reads_edit_distance", \
"discordant_reads_cutoff", "merged", "paired_and_single", "single_end", "outdir", \
"illumina_reads_directory", "target_file", "help", "memory", "read_pairs_pattern", \
"single_pattern", "use_blastx", "num_forks", "cov_cutoff", "blastx_evalue", \
"paralog_warning_min_len_percent", "translate_target_file_for_blastx", "use_trimmomatic", \
"trimmomatic_leading_quality", "trimmomatic_trailing_quality", "trimmomatic_min_length", \
"trimmomatic_sliding_window_size", "trimmomatic_sliding_window_quality", "run_intronerate", \
"bbmap_subfilter", "combine_read_files", "combine_read_files_num_fields", "namelist"]

params.each { entry ->
  if (! allowed_params.contains(entry.key)) {
      println("The parameter <${entry.key}> is not known");
      exit 0;
  }
}


//////////////////////////////////
//  Target gene sequences file  //
//////////////////////////////////

Channel
  .fromPath("${params.target_file}", checkIfExists: true)
  .first()
  .set { target_file_ch }


end_field = params.combine_read_files_num_fields - 1  // Due to zero-based indexing

def getLibraryId( prefix ){
  /* 
  Function for grouping reads from multiple lanes, based on a shared filename 
  prefix preceeding the first underscore.
  */

  filename_list = prefix.split("_")
  groupby_select = filename_list[0..end_field]
  groupby_joined = groupby_select.join("_")
}


/////////////////////////////////////////////////////////
//  Create 'namelist.txt' file and associated channel  //
/////////////////////////////////////////////////////////

def user_provided_namelist_for_filtering = []

if (params.namelist) {
  user_provided_namelist_file = file("${params.namelist}", checkIfExists: true)
    .readLines()
    .each { user_provided_namelist_for_filtering << it }
  Channel
  .fromPath("${params.namelist}", checkIfExists: true)
  .first()
  .set { namelist_ch }

} else if (!params.single_end && !params.combine_read_files) {
  Channel
  .fromFilePairs("${params.illumina_reads_directory}/*_{$params.read_pairs_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
    flat : true, checkIfExists: true)
  .collectFile(name: "${params.outdir}/01_namelist/namelist.txt") { item -> item[0] + "\n" }
  .first()
  .set { namelist_ch }

} else if (!params.single_end && params.combine_read_files) {
  Channel
  .fromFilePairs("${params.illumina_reads_directory}/*_{$params.read_pairs_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
    flat : true, checkIfExists: true)
  .map { prefix, file1, file2 -> tuple(getLibraryId(prefix), file1, file2) }
  .groupTuple(sort:true)
  .collectFile(name: "${params.outdir}/01_namelist/namelist.txt") { item -> item[0] + "\n" }
  .first()
  .set { namelist_ch }

} else if (params.single_end && !params.combine_read_files) {
  Channel
  .fromPath("${params.illumina_reads_directory}/*_{$params.single_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
    checkIfExists: true)
  .map { file -> file.baseName.split("_${params.single_pattern}")[0] } // THIS NEEDS TO BE UNIQUE
  .unique()
  .collectFile(name: "${params.outdir}/01_namelist/namelist.txt", newLine: true)
  .first()
  .set { namelist_ch }

} else if (params.single_end && params.combine_read_files) {
  Channel
  .fromPath("${params.illumina_reads_directory}/*_{$params.single_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
    checkIfExists: true)
  .map { file -> tuple((file.baseName.split('_')[0..end_field]).join("_"), file) }
  .groupTuple(sort:true)
  .collectFile(name: "${params.outdir}/01_namelist/namelist.txt") { item -> item[0] + "\n" }
  .first()
  .set { namelist_ch }
}



if (user_provided_namelist_for_filtering) {
  user_provided_namelist_for_filtering = user_provided_namelist_for_filtering.findAll { item -> !item.isEmpty() }

  log.info("""
    INFO: A namelist has been supplied by the user. Only the following samples will be processed: ${user_provided_namelist_for_filtering}\n""".stripIndent())
}


//////////////////////////////
//  Illumina reads channel  //
//////////////////////////////

/*
Single-end reads.
Don't group reads from multi-lane (default).
*/
if (params.single_end && !params.combine_read_files && user_provided_namelist_for_filtering) {
  Channel
  .fromPath("${params.illumina_reads_directory}/*_{$params.single_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
    checkIfExists: true)
  .map { file -> tuple(file.baseName.split("_${params.single_pattern}")[0], file) } // THIS NEEDS TO BE UNIQUE
  .filter { it[0] in user_provided_namelist_for_filtering }
  // .view()
  .set { illumina_reads_single_end_ch }

} else if (params.single_end && !params.combine_read_files && 
  !user_provided_namelist_for_filtering) {
  Channel
  .fromPath("${params.illumina_reads_directory}/*_{$params.single_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
    checkIfExists: true)
  .map { file -> tuple(file.baseName.split("_${params.single_pattern}")[0], file) } // THIS NEEDS TO BE UNIQUE
  .set { illumina_reads_single_end_ch }

} else if (params.single_end && params.combine_read_files && user_provided_namelist_for_filtering) {
  Channel
  .fromPath("${params.illumina_reads_directory}/*_{$params.single_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
  checkIfExists: true)
  .map { file -> tuple((file.baseName.split('_')[0..end_field]).join("_"), file) }
  .groupTuple(sort:true)
  // .view()
  .filter { it[0] in user_provided_namelist_for_filtering }
  // .view()
  .set { illumina_reads_single_end_ch }

} else if (params.single_end && params.combine_read_files && !user_provided_namelist_for_filtering) {
  Channel
  .fromPath("${params.illumina_reads_directory}/*_{$params.single_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
  checkIfExists: true)
  .map { file -> tuple((file.baseName.split('_')[0..end_field]).join("_"), file) }
  .groupTuple(sort:true)
  .set { illumina_reads_single_end_ch }

} else {
  illumina_reads_single_end_ch = Channel.empty()
}


/*
Paired-end reads and a file of unpaired reads.
*/
if (params.paired_and_single) {
  Channel
  .fromFilePairs("${params.illumina_reads_directory}/*_{$params.read_pairs_pattern,$params.single_pattern}*.{fastq.gz,fastq,fq.gz,fq}", flat : true,
  checkIfExists: true, size: 3)
  .set { illumina_paired_reads_with_unpaired_ch }
} else {
  illumina_paired_reads_with_unpaired_ch = Channel.empty()
}


/* 
Paired-end reads.
Don't group reads from multi-lane (default).
*/
if (!params.paired_and_single && !params.single_end  && !params.combine_read_files && user_provided_namelist_for_filtering) {
  Channel
    .fromFilePairs("${params.illumina_reads_directory}/*_{$params.read_pairs_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
    flat : true, checkIfExists: true)
    .filter { it[0] in user_provided_namelist_for_filtering }
    // .view()
    .set { illumina_paired_reads_ch }

} else if (!params.paired_and_single && !params.single_end  && !params.combine_read_files && !user_provided_namelist_for_filtering) {
    Channel
    .fromFilePairs("${params.illumina_reads_directory}/*_{$params.read_pairs_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
    flat : true, checkIfExists: true)
    // .view()
    .set { illumina_paired_reads_ch }

} else if (!params.paired_and_single && !params.single_end  && params.combine_read_files && user_provided_namelist_for_filtering) {
    Channel
    .fromFilePairs("${params.illumina_reads_directory}/*_{$params.read_pairs_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
    flat : true, checkIfExists: true)
    .map { prefix, file1, file2 -> tuple(getLibraryId(prefix), file1, file2) }
    .groupTuple(sort:true)
    .filter { it[0] in user_provided_namelist_for_filtering }
    // .view()
    .set { illumina_paired_reads_ch }

} else if (!params.paired_and_single && !params.single_end && params.combine_read_files && !user_provided_namelist_for_filtering) {
    Channel
    .fromFilePairs("${params.illumina_reads_directory}/*_{$params.read_pairs_pattern}*.{fastq.gz,fastq,fq.gz,fq}", \
    flat : true, checkIfExists: true)
    .map { prefix, file1, file2 -> tuple(getLibraryId(prefix), file1, file2) }
    .groupTuple(sort:true)
    .set { illumina_paired_reads_ch }

} else {
  illumina_paired_reads_ch = Channel.empty()
}


/*
Channel of gene names for 'paralog_retriever.py' script
*/
Channel
  .fromPath("${params.target_file}", checkIfExists: true)
  .splitFasta( record: [id: true, seqString: true ])
  .map { it.id.replaceFirst(~/.*-/, '') }
  .unique()
  .set { gene_names_ch }
  // gene_names_ch.view { "value: $it" }


/////////////////////////////
//  DEFINE DSL2 PROCESSES  //
/////////////////////////////

process TRANSLATE_TARGET_FILE {
  /*
  If the flag `--translate_target_file_for_blastx` is set, translate nucleotide target file.
  */

  // echo true
  label 'in_container'
  publishDir "${params.outdir}/00_translated_target_file", mode: 'copy'

  when:
    params.translate_target_file_for_blastx

  input:
    path(target_file_nucleotides)

  output:
    path "target_file_translated.fasta", emit: translated_target_file
    path("translation_warnings.txt")

  script:
    """
    #!/usr/bin/env python

    from Bio import SeqIO

    translated_seqs_to_write = []
    with open("${target_file_nucleotides}", 'r') as target_file_nucleotides:
      seqs = SeqIO.parse(target_file_nucleotides, 'fasta')
      with open('translation_warnings.txt', 'w') as translation_warnings:
        for seq in seqs:
          if len(seq.seq) % 3 != 0:
            translation_warnings.write(f"WARNING: sequence for gene {seq.name} is not a multiple of 3. Translating anyway...\\n")
          protein_translation = seq.translate()
          protein_translation.name = seq.name
          protein_translation.id = seq.id
          protein_translation.description = 'translated sequence from nucleotide target file'
          num_stop_codons = protein_translation.seq.count('*')
          if num_stop_codons != 0:
            translation_warnings.write(f'WARNING: stop codons present in translation of sequence {seq.name}, please check\\n')
          translated_seqs_to_write.append(protein_translation)

    with open('target_file_translated.fasta', 'w') as translated_handle:
      SeqIO.write(translated_seqs_to_write, translated_handle, 'fasta')

    """
}



process COMBINE_LANES_PAIRED_END {
  /*
  If `--combine_read_files` flag is set, combine lanes when using paired-end R1 and R2 reads.
  */

  label 'in_container'
  // echo true
  publishDir "$params.outdir/02_reads_combined_lanes", mode: 'copy', pattern: "*.fastq*"

  if (params.num_forks) {
    maxForks params.num_forks
  }

  when:
    params.combine_read_files

  input:
    tuple val(prefix), path(reads_R1), path(reads_R2)

  output:
    tuple val(prefix), path("*R1.fastq*"), path("*R2.fastq*"), emit: combined_lane_paired_reads

  script:
    """
    first_file=\$(echo $reads_R1 | cut -d' ' -f1)
    echo \$first_file

    if [[ \$first_file = *.gz ]]
      then 
        cat $reads_R1 > ${prefix}_combinedLanes_R1.fastq.gz
        cat $reads_R2 > ${prefix}_combinedLanes_R2.fastq.gz
    fi

    if [[ \$first_file = *.fq ]] || [[ \$first_file = *.fastq ]]
      then 
        cat $reads_R1 > ${prefix}_combinedLanes_R1.fastq
        cat $reads_R2 > ${prefix}_combinedLanes_R2.fastq
    fi
    """
}


process COMBINE_LANES_SINGLE_END {
  /*
  If `--combine_read_files` flag is set, combine lanes when using single-end reads only,
  */

  label 'in_container'
  // echo true
  publishDir "$params.outdir/02_reads_combined_lanes", mode: 'copy', pattern: "*.fastq*"

  if (params.num_forks) {
    maxForks params.num_forks
  }

  when:
    params.combine_read_files

  input:
    tuple val(prefix), path(reads_single)

  output:
    tuple val(prefix), path("*single.fastq*"), emit: combined_lane_single_reads_ch

  script:
    """
    first_file=\$(echo $reads_single | cut -d' ' -f1)
    echo \$first_file

    if [[ \$first_file = *.gz ]]
      then 
        cat $reads_single > ${prefix}_combinedLanes_single.fastq.gz
    fi

    if [[ \$first_file = *.fq ]] || [[ \$first_file = *.fastq ]]
      then 
        cat $reads_single > ${prefix}_combinedLanes_single.fastq
    fi
    """
}


process TRIMMOMATIC_PAIRED {
  /*
  If `--use_trimmomatic` flag is set, run optional Trimmomatic step for paired-end reads.
  */

  // echo true
  label 'in_container'
  publishDir "$params.outdir/03a_trimmomatic_logs", mode: 'copy', pattern: "*.log"
  publishDir "$params.outdir/03b_trimmomatic_paired_and_single_reads", mode: 'copy', pattern: "*_paired.fq*"
  publishDir "$params.outdir/03b_trimmomatic_paired_and_single_reads", mode: 'copy', pattern: "*_R1-R2_unpaired.fq*"


  if (params.num_forks) {
    maxForks params.num_forks
  }

  when:
    params.use_trimmomatic

  input:
    tuple val(prefix), path(reads_R1), path(reads_R2)

  output:
    path("*")
    tuple val(prefix), path("*R1_paired*"), path("*R2_paired*"), path("*R1-R2_unpaired*"), emit: trimmed_paired_and_orphaned_ch

  script:
    read_pairs_pattern_list = params.read_pairs_pattern?.tokenize(',')

    """
    R1=${reads_R1}
    R2=${reads_R2}
    sampleID_R1=\${R1%_${read_pairs_pattern_list[0]}*}
    sampleID_R2=\${R2%_${read_pairs_pattern_list[1]}*}

    echo \$R1
    echo \$R2

    if [[ \$R1 = *.gz ]]
      then 
        R1_filename_strip_gz="\${R1%.gz}"
        fastq_extension="\${R1_filename_strip_gz##*.}"

        output_forward_paired=\${sampleID_R1}_R1_paired.fq.gz
        output_reverse_paired=\${sampleID_R2}_R2_paired.fq.gz
        output_forward_unpaired=\${sampleID_R1}_R1_unpaired.fq.gz
        output_reverse_unpaired=\${sampleID_R2}_R2_unpaired.fq.gz
        output_both_unpaired=\${sampleID_R1}_R1-R2_unpaired.fq.gz

      else
        fastq_extension="\${R1##*.}"

        output_forward_paired=\${sampleID_R1}_R1_paired.fq
        output_reverse_paired=\${sampleID_R2}_R2_paired.fq
        output_forward_unpaired=\${sampleID_R1}_R1_unpaired.fq
        output_reverse_unpaired=\${sampleID_R2}_R2_unpaired.fq
        output_both_unpaired=\${sampleID_R1}_R1-R2_unpaired.fq
    fi

    # Write adapters fasta file:
    echo -e ">PrefixPE/1\nTACACTCTTTCCCTACACGACGCTCTTCCGATCT\n>PrefixPE/2\nGTGACTGGAGTTCAGACGTGTGCTCTTCCGATCT\n>PE1\nTACACTCTTTCCCTACACGACGCTCTTCCGATCT\n>PE1_rc\nAGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTA\n>PE2\nGTGACTGGAGTTCAGACGTGTGCTCTTCCGATCT\n>PE2_rc\nAGATCGGAAGAGCACACGTCTGAACTCCAGTCA" > TruSeq3-PE-2.fa

    # Run Trimmomtic:
    trimmomatic PE -phred33 -threads ${task.cpus} \
    ${reads_R1} ${reads_R2} \${output_forward_paired} \${output_forward_unpaired} \
    \${output_reverse_paired} \${output_reverse_unpaired} \
    ILLUMINACLIP:TruSeq3-PE-2.fa:2:30:10:1:true \
    LEADING:${params.trimmomatic_leading_quality} \
    TRAILING:${params.trimmomatic_trailing_quality} \
    SLIDINGWINDOW:${params.trimmomatic_sliding_window_size}:${params.trimmomatic_sliding_window_quality} \
    MINLEN:${params.trimmomatic_min_length} 2>&1 | tee \${sampleID_R1}.log 
    cat \${output_forward_unpaired} \${output_reverse_unpaired} > \${output_both_unpaired}
    """
}


process TRIMMOMATIC_SINGLE {
  /*
  If `--use_trimmomatic` flag is set, run optional Trimmomatic step for single-end reads.
  */

  // echo true
  label 'in_container'
  publishDir "$params.outdir/03a_trimmomatic_logs", mode: 'copy', pattern: "*.log"
  publishDir "$params.outdir/03c_trimmomatic_single_reads", mode: 'copy', pattern: "*_single*"

  if (params.num_forks) {
    maxForks params.num_forks
  }

  when:
    params.use_trimmomatic

  input:
    tuple val(prefix), path(reads_single)

  output:
    path("*")
    tuple val(prefix), file("*single*"), emit: trimmed_single_ch

  script:
    """
    single=${reads_single}


    if [[ \$single = *.gz ]]
      then 
        output_single=${prefix}_trimmed_single.fq.gz
      else
        output_single=${prefix}_trimmed_single.fq
    fi

    echo -e ">TruSeq3_IndexedAdapter\nAGATCGGAAGAGCACACGTCTGAACTCCAGTCAC\n>TruSeq3_UniversalAdapter\nAGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTA\n" > TruSeq3-SE.fa
    trimmomatic SE -phred33 -threads ${task.cpus} \
    ${reads_single} \${output_single} ILLUMINACLIP:TruSeq3-SE.fa:2:30:10:1:true \
    LEADING:${params.trimmomatic_leading_quality} \
    TRAILING:${params.trimmomatic_trailing_quality} \
    SLIDINGWINDOW:${params.trimmomatic_sliding_window_size}:${params.trimmomatic_sliding_window_quality} \
    MINLEN:${params.trimmomatic_min_length} 2>&1 | tee ${prefix}.log 
    """
}



process READS_FIRST_SINGLE_END {
  /*
  Run reads_first.py for input files: [single_end]
  */

  // echo true
  label 'in_container'
  publishDir "${params.outdir}/06_summary_stats", mode: 'copy', pattern: "${prefix}/${prefix}_genes_with_supercontigs.csv"
  publishDir "${params.outdir}/06_summary_stats", mode: 'copy', pattern: "${prefix}/${prefix}_supercontigs_with_discordant_reads.csv"

  if (params.num_forks) {
    maxForks params.num_forks
  }

  when:
    params.single_end

  input:
    path(target_file)
    tuple val(prefix), path(reads_single)

  output:
    path("${prefix}"), emit: reads_first_with_single_end_ch optional true
    path("${prefix}/${prefix}_genes_with_supercontigs.csv") optional true
    path("${prefix}/${prefix}_supercontigs_with_discordant_reads.csv") optional true

  script:
    def command_list = []

    if (params.nosupercontigs) {
      command_list << "--nosupercontigs"
      }
    if (params.memory) {
      command_list << "--memory ${params.memory}"
      }
    if (params.discordant_reads_edit_distance) {
      command_list << "--discordant_reads_edit_distance ${params.discordant_reads_edit_distance}"
      }
    if (params.discordant_reads_cutoff) {
      command_list << "--discordant_reads_cutoff ${params.discordant_reads_cutoff}"
      } 
    if (params.merged) {
      command_list << "--merged"
      }
    if (!params.use_blastx && !params.translate_target_file_for_blastx) {
      command_list << "--bwa"
    }
    if (params.blastx_evalue) {
      command_list << "--evalue ${params.blastx_evalue}"
    }
    if (params.paralog_warning_min_len_percent) {
      command_list << "--paralog_warning_min_length_percentage ${params.paralog_warning_min_len_percent}"
    }
    if (params.cov_cutoff) {
      command_list << "--cov_cutoff ${params.cov_cutoff}"
    }
    if (params.cleanup) {
      cleanup = "python /HybPiper/cleanup.py ${prefix}"
    } else {
      cleanup = ''
    }
    reads_first_command = "python /HybPiper/reads_first.py -b ${target_file} -r ${reads_single} --prefix ${prefix} --cpu ${task.cpus} " + command_list.join(' ')

    """
    echo ${reads_first_command}
    ${reads_first_command}
    ${cleanup}
    """
}


process READS_FIRST_PAIRED_AND_SINGLE_END {
  /*
  Run reads_first.py for input files: [R1, R1, R1-R2_unpaired]
  */

  //echo true
  label 'in_container'
  publishDir "${params.outdir}/06_summary_stats", mode: 'copy', pattern: "${pair_id}/${pair_id}_genes_with_supercontigs.csv"
  publishDir "${params.outdir}/06_summary_stats", mode: 'copy', pattern: "${pair_id}/${pair_id}_supercontigs_with_discordant_reads.csv"

  if (params.num_forks) {
    maxForks params.num_forks
  }

  when:
    (params.use_trimmomatic || params.paired_and_single)

  input:
    path(target_file) 
    tuple val(pair_id), path(reads_R1), path(reads_R2), path(reads_unpaired)

  output:
    path("${pair_id}"), emit: reads_first_with_unPaired_ch optional true
    path("${pair_id}/${pair_id}_genes_with_supercontigs.csv") optional true
    path("${pair_id}/${pair_id}_supercontigs_with_discordant_reads.csv") optional true

  script:
    def command_list = []

    if (params.nosupercontigs) {
      command_list << "--nosupercontigs"
      }
    if (params.memory) {
      command_list << "--memory ${params.memory}"
      }
    if (params.bbmap_subfilter) {
      command_list << "--bbmap_subfilter ${params.bbmap_subfilter}"
      }
    if (params.discordant_reads_edit_distance) {
      command_list << "--discordant_reads_edit_distance ${params.discordant_reads_edit_distance}"
      }
    if (params.discordant_reads_cutoff) {
      command_list << "--discordant_reads_cutoff ${params.discordant_reads_cutoff}"
      } 
    if (params.merged) {
      command_list << "--merged"
      }
    if (!params.use_blastx && !params.translate_target_file_for_blastx) {
      command_list << "--bwa"
    }
    if (params.blastx_evalue) {
      command_list << "--evalue ${params.blastx_evalue}"
    }
    if (params.paralog_warning_min_len_percent) {
      command_list << "--paralog_warning_min_length_percentage ${params.paralog_warning_min_len_percent}"
    }
    if (params.cov_cutoff) {
      command_list << "--cov_cutoff ${params.cov_cutoff}"
    }
    if (params.cleanup) {
      cleanup = "python /HybPiper/cleanup.py ${pair_id}"
    } else {
      cleanup = ''
    }
    reads_first_command = "python /HybPiper/reads_first.py -b ${target_file} -r ${reads_R1} ${reads_R2} --unpaired ${reads_unpaired} --prefix ${pair_id} --cpu ${task.cpus} " + command_list.join(' ')

    script:
    """
    echo ${reads_first_command}
    ${reads_first_command}
    ${cleanup}
    """
  } 


process READS_FIRST_PAIRED_END {
  /*
  Run reads_first.py for input files: [R1, R1]
  */

  // echo true
  label 'in_container'
  publishDir "${params.outdir}/06_summary_stats", mode: 'copy', pattern: "${pair_id}/${pair_id}_genes_with_supercontigs.csv"
  publishDir "${params.outdir}/06_summary_stats", mode: 'copy', pattern: "${pair_id}/${pair_id}_supercontigs_with_discordant_reads.csv"

  if (params.num_forks) {
    maxForks params.num_forks
  }

  when:
    (!params.paired_and_single && !params.single_end && !params.use_trimmomatic)

  input:
    path(target_file) 
    tuple val(pair_id), path(reads_R1), path(reads_R2)

  output:
    path("${pair_id}"), emit: reads_first_ch optional true
    path("${pair_id}/${pair_id}_genes_with_supercontigs.csv") optional true
    path("${pair_id}/${pair_id}_supercontigs_with_discordant_reads.csv") optional true

  script:
    def command_list = []

    if (params.nosupercontigs) {
      command_list << "--nosupercontigs"
      }
    if (params.memory) {
      command_list << "--memory ${params.memory}"
      }
    if (params.bbmap_subfilter) {
      command_list << "--bbmap_subfilter ${params.bbmap_subfilter}"
      }
    if (params.discordant_reads_edit_distance) {
      command_list << "--discordant_reads_edit_distance ${params.discordant_reads_edit_distance}"
      }
    if (params.discordant_reads_cutoff) {
      command_list << "--discordant_reads_cutoff ${params.discordant_reads_cutoff}"
      }
    if (params.merged) {
      command_list << "--merged"
      }
    if (!params.use_blastx && !params.translate_target_file_for_blastx) {
      command_list << "--bwa"
    }
    if (params.blastx_evalue) {
      command_list << "--evalue ${params.blastx_evalue}"
    }
    if (params.paralog_warning_min_len_percent) {
      command_list << "--paralog_warning_min_length_percentage ${params.paralog_warning_min_len_percent}"
    }
    if (params.cov_cutoff) {
      command_list << "--cov_cutoff ${params.cov_cutoff}"
    }
    if (params.cleanup) {
      cleanup = "python /HybPiper/cleanup.py ${pair_id}"
    } else {
      cleanup = ''
    }
    reads_first_command = "python /HybPiper/reads_first.py -b ${target_file} -r ${reads_R1} ${reads_R2} --prefix ${pair_id} --cpu ${task.cpus} " + command_list.join(' ')


    script:
    """
    echo "about to try command: ${reads_first_command}"
    ${reads_first_command}
    ${cleanup}
    """
}


process VISUALISE {
  /*
  Run the get_seq_lengths.py script
  */

  // echo true
  label 'in_container'
  publishDir "${params.outdir}/05_visualise", mode: 'copy'

  input:
    path(reads_first)
    path(target_file)
    path(namelist)

  output:
    path("seq_lengths.txt"), emit: seq_lengths_ch
    path("heatmap.png")

  script:
    """
    python /HybPiper/get_seq_lengths.py ${target_file} ${namelist} dna > seq_lengths.txt
    Rscript /HybPiper/gene_recovery_heatmap_ggplot.R
    """
}


process SUMMARY_STATS {
/*
Run hybpiper_stats.py script.
*/

  // echo true
  label 'in_container'
  publishDir "${params.outdir}/06_summary_stats", mode: 'copy'

  input:
    path(reads_first)
    path(seq_lengths) 
    path(namelist)

  output:
    path("stats.txt"), emit: stats_file

  script:
    if (params.translate_target_file_for_blastx || params.use_blastx) {
    """
    python /HybPiper/hybpiper_stats.py ${seq_lengths} ${namelist} --blastx_adjustment > stats.txt
    """
    } else {
    """
    python /HybPiper/hybpiper_stats.py ${seq_lengths} ${namelist} > stats.txt
    """
    } 
}


process INTRONERATE {
  /*
  Run intronerate.py script.
  */

  // echo true
  label 'in_container'

  input:
    path(reads_first)

  output:
    path(reads_first), emit: intronerate_ch optional true

  script:
    """
    echo ${reads_first}
    python /HybPiper/intronerate.py --prefix ${reads_first}
    """
}


process PARALOGS {
  /*
  Run paralog_investigator.py script.
  */

  //echo true
  label 'in_container'
  publishDir "${params.outdir}/04_processed_gene_directories", mode: 'copy'

  if (params.num_forks) {
      maxForks params.num_forks
  }

  input:
    path(intronerate_complete) 

  output:
    path(intronerate_complete), emit: paralogs_ch optional true 

  script:
    """
    python /HybPiper/paralog_investigator.py ${intronerate_complete}
    """
}


process RETRIEVE_SEQUENCES {
  /*
  Run the retrieve_sequences.py script for all sequence types.
  */

  // echo true
  label 'in_container'
  publishDir "${params.outdir}/07_sequences_dna", mode: 'copy', pattern: "*.FNA"
  publishDir "${params.outdir}/08_sequences_aa", mode: 'copy', pattern: "*.FAA"
  publishDir "${params.outdir}/09_sequences_intron", mode: 'copy', pattern: "*introns.fasta"
  publishDir "${params.outdir}/10_sequences_supercontig", mode: 'copy', pattern: "*supercontig.fasta"

  input:
    path(paralog_complete)
    path(target_file)


  output:
    path("*.FNA")
    path("*.FAA")
    path("*.fasta")

  script:
    """
    python /HybPiper/retrieve_sequences.py ${target_file} . dna
    python /HybPiper/retrieve_sequences.py ${target_file} . aa
    python /HybPiper/retrieve_sequences.py ${target_file} . intron
    python /HybPiper/retrieve_sequences.py ${target_file} . supercontig
    """
}


process PARALOG_RETRIEVER {
  /*
  Run paralog_retriever.py script.
  */

  //echo true
  label 'in_container'
  publishDir "${params.outdir}/11_paralogs", mode: 'copy', pattern: "*.paralogs.fasta"
  publishDir "${params.outdir}/12_paralogs_noChimeras", mode: 'copy', pattern: "*.paralogs_noChimeras.fasta"
  publishDir "${params.outdir}/12_paralogs_noChimeras/logs", mode: 'copy', pattern: "*mylog*"

  input:
    path(paralog_complete_list)
    path(namelist)
    val(gene_list)


  output:
    path("*.fasta")
    path("*.mylog*")  

  script:
    assert (gene_list in List)
    list_of_names = gene_list.join(' ') // Note that this is necessary so that the list isn't of the form [4471, 4527, etc]
    """
    for gene_name in ${list_of_names}
    do
      python /HybPiper/paralog_retriever.py ${namelist} \${gene_name} > \${gene_name}.paralogs_noChimeras.fasta 2> \${gene_name}.paralogs.fasta
    done
    """
}


///////////////////////////////////
//  OPTIONAL workflow processes  //
///////////////////////////////////


process LUCY_PROCESS {
  /*
  BEAGLE
  */

  echo true
  label 'in_container'
  publishDir "${params.outdir}/lucy_beagle_folder", mode: 'copy'


  input:
    tuple val(prefix), path(reads_R1), path(reads_R2)

  output:
    path "${reads_R1}", emit: lucy_ch


  script:
    """
    echo ${reads_R1}

    """
} 


workflow lucy_workflow {

  LUCY_PROCESS( illumina_paired_reads_ch )

}



////////////////////////
//  Define workflows  //
////////////////////////

workflow {

  // Run OPTIONAL translate target file step:
  TRANSLATE_TARGET_FILE( target_file_ch )

  // Set up input channel for target file:
  if (!params.translate_target_file_for_blastx) {
    target_file_ch = target_file_ch
  } else {
    target_file_ch = TRANSLATE_TARGET_FILE.out.translated_target_file
  }

  // Run OPTIONAL combine read file step: 
  COMBINE_LANES_PAIRED_END( illumina_paired_reads_ch )
  COMBINE_LANES_SINGLE_END( illumina_reads_single_end_ch )

  // Set up correct channel for combined vs non-combined:
  if (params.combine_read_files) {
    trimmomatic_PE_input_ch = COMBINE_LANES_PAIRED_END.out.combined_lane_paired_reads
    trimmomatic_SE_input_ch = COMBINE_LANES_SINGLE_END.out.combined_lane_single_reads_ch
  } else {
    trimmomatic_PE_input_ch = illumina_paired_reads_ch
    trimmomatic_SE_input_ch = illumina_reads_single_end_ch
  }

  // Run OPTIONAL trimmomatic QC step:
  TRIMMOMATIC_PAIRED( trimmomatic_PE_input_ch )
  TRIMMOMATIC_SINGLE( trimmomatic_SE_input_ch )

  // Set up input channels for reads_first.py:
  if (params.use_trimmomatic) {
    reads_first_with_single_end_only_input_ch = TRIMMOMATIC_SINGLE.out.trimmed_single_ch
    reads_first_with_unpaired_input_ch = TRIMMOMATIC_PAIRED.out.trimmed_paired_and_orphaned_ch
    reads_first_no_unpaired_input_ch = Channel.empty()
  } else if (params.combine_read_files) {
    reads_first_with_single_end_only_input_ch = COMBINE_LANES_SINGLE_END.out.combined_lane_single_reads_ch
    reads_first_with_unpaired_input_ch = Channel.empty()
    reads_first_no_unpaired_input_ch = COMBINE_LANES_PAIRED_END.out.combined_lane_paired_reads
  } else {
    reads_first_with_single_end_only_input_ch = illumina_reads_single_end_ch
    reads_first_with_unpaired_input_ch = illumina_paired_reads_with_unpaired_ch
    reads_first_no_unpaired_input_ch = illumina_paired_reads_ch
  }

  // Run reads_first.py:
  READS_FIRST_PAIRED_AND_SINGLE_END( target_file_ch, reads_first_with_unpaired_input_ch )
  READS_FIRST_PAIRED_END( target_file_ch, reads_first_no_unpaired_input_ch )
  READS_FIRST_SINGLE_END ( target_file_ch, reads_first_with_single_end_only_input_ch )

  // Run get_seq_lengths.py and gene_recovery_heatmap_ggplot.R:
  VISUALISE( READS_FIRST_PAIRED_AND_SINGLE_END.out.reads_first_with_unPaired_ch.collect().mix(READS_FIRST_PAIRED_END.out.reads_first_ch).collect().mix(READS_FIRST_SINGLE_END.out.reads_first_with_single_end_ch).collect(), target_file_ch, namelist_ch) 

  // Run hybpiper_stats.py:
  SUMMARY_STATS( READS_FIRST_PAIRED_AND_SINGLE_END.out.reads_first_with_unPaired_ch.collect().mix(READS_FIRST_PAIRED_END.out.reads_first_ch).collect().mix(READS_FIRST_SINGLE_END.out.reads_first_with_single_end_ch).collect(), VISUALISE.out.seq_lengths_ch, namelist_ch ) 

  // Set up conditional channels to skip or include intronerate.py:
  (reads_first_channel_1, reads_first_channel_2) = (params.run_intronerate ? 
  [Channel.empty(), READS_FIRST_PAIRED_AND_SINGLE_END.out.reads_first_with_unPaired_ch.mix(READS_FIRST_PAIRED_END.out.reads_first_ch).mix(READS_FIRST_SINGLE_END.out.reads_first_with_single_end_ch)] : [READS_FIRST_PAIRED_AND_SINGLE_END.out.reads_first_with_unPaired_ch.mix(READS_FIRST_PAIRED_END.out.reads_first_ch).mix(READS_FIRST_SINGLE_END.out.reads_first_with_single_end_ch), Channel.empty()] )

  // Run OPTIONAL Intronerate step:
  INTRONERATE( reads_first_channel_2 )

  // Run paralog_investigator.py script:
  PARALOGS( INTRONERATE.out.intronerate_ch.mix(reads_first_channel_1) )

  // Run retrieve_sequences.py script for all sequence types:
  RETRIEVE_SEQUENCES( PARALOGS.out.paralogs_ch.collect(), target_file_ch )

  // Run paralog_retriever.py script: 
  PARALOG_RETRIEVER( PARALOGS.out.paralogs_ch.collect(), namelist_ch, gene_names_ch.collect() )
} 

///////////////////////////////////////////////////
/////////////////  End of script  /////////////////
///////////////////////////////////////////////////
