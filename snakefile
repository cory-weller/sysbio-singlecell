#!/usr/bin/env python

#!/usr/bin/env python3
# coding: utf-8

import sys
sys.tracebacklimit = 0

try:
    from sysbio_sc import *
except ModuleNotFoundError:
    sys.path.append('src')
    from sysbio_sc import *


#===================================================================================================
# 01 Load config
#===================================================================================================

project_dir = Path(os.getcwd())                                 # Returns PosixPath object
config_file = project_dir / 'config.yaml'                 # Default config name within project_dir
configfile: 'config.yaml'                              # Loads as DotDict; exits if cannot load
config = DotDict(config)

LIBRARIES = import_config('cellranger-libraries.yaml')
data_dir = project_dir / config.data_dir
synapse_metadata_summary = data_dir / config.synapse.metadata_summary

# Convert paths to posix strings
data_dir = data_dir.as_posix()
synapse_metadata_summary = synapse_metadata_summary.as_posix()

localrules: get_metadata, build_library_mapping, build_ref_vcf
lscratch_tmpdir = "/lscratch/$SLURM_JOB_ID"

# ── Rules ──────────────────────────────────────────────────────
rule all: 
    input: expand(f"{data_dir}/DEMUX/{{libraryID}}/cellSNP.cells.vcf.gz", libraryID=list(LIBRARIES.keys())[:1])
    # f"{data_dir}/dsc-pileup-ref.vcf.gz"
    #expand(f"{data_dir}/CELLBENDER/{{libraryID}}/output.h5", libraryID=list(LIBRARIES.keys())),
            
           #




rule get_metadata:
    """
    Iterates over synapse IDs defined in config.yaml, recursively,
    retrieving file metadata and writing to separate metadata.tsv files.
    Outputs metadata in nested directories, reflecting file structure on synapse.
    Requires a synapse authentication token, its location defined in config.yaml
    """
    output: synapse_metadata_summary
    conda: 'envs/sysbio_singlecell.yaml'
    shell: 
        """
        python3 src/01_get_metadata.py
        """


rule download_data:
    """
    Iterates over the combined metadata folder. For every file, in the list,
    if the file does not exist: it is downloaded using synapse get.
    If the file exists,
        If file.md5 has not been generated, it is generated.
        file.md5 is compared to the metadata table.
        if the md5 values do not match,
            the file and file.md5 are deleted.
            The bad file is logged as an error.
    Only if no errors occur does .download-check get generated.
    """
    input: synapse_metadata_summary
    output: f"{data_dir}/download_data.done"
    conda: 'envs/sysbio_singlecell'
    shell:
        """
        python3 src/02_file_download.py
        touch {output}
        """

rule build_library_mapping:
    '''
    This rule is specific to this project / dataset. It must be modified depending on the format
    of input metadata in order to get a list of libraries.
    '''
    input: ancient(f"{data_dir}/{config.synapse.metadata_summary}")
    output: 'cellranger-libraries.yaml'
    conda: 'envs/sysbio_singlecell'
    run:
        def get_library_file(fn1, fn2):
            with open(fn1, 'r') as infile:
                for line in infile:
                    line = line.rstrip().split()
                    if line[1].endswith(fn2):
                        return(line[1])
            # After reaching end of file without a match
            raise FileNotFoundError(f"Could not find file matching {fn2} within column 2 of ${fn1}")
        # generate library ID file if it does not exist
        library_metadata_file = get_library_file(fn1=input[0],
                                                fn2=config.metadata.sample_libraries)
        libraries = []
        delim=','
        header_start = 'specimenID'
        with open(data_dir / library_metadata_file, 'r') as infile:
            for line in infile:
                if line.startswith(header_start):
                    continue
                libraries.append(line.split(delim)[1])
        libraries = sorted(list(set(libraries)))
        library_yaml = { x : x+'-GEX' for x in libraries}
        
        with open(output[0], 'w') as outfile:
            yaml.dump(library_yaml, outfile, default_flow_style=False, sort_keys=False)

rule run_cellranger:
    '''
    This rule is specific to this project / dataset. It must be modified depending on the format
    of input metadata in order to get a list of libraries.
    '''
    input: ancient('cellranger-libraries.yaml')
    output: f"{data_dir}/CELLRANGER/{{libraryID}}/raw_feature_bc_matrix.h5"
    conda: 'envs/sysbio_singlecell'
    params:
        PAR_SLURM_ID=os.environ['SLURM_JOB_ID'],
        OUTDIR=os.getcwd()
    envmodules: 'cellranger/10.1.0'
    shell:
        '''
        if [ -z ${{SLURM_JOB_ID:-}} ]; then export SLURM_JOB_ID={params.PAR_SLURM_ID}; fi; export TMPDIR=/lscratch/$SLURM_JOB_ID
        python3 src/cellranger.py --library {wildcards.libraryID} && touch {output}
        '''

rule run_cellbender:
    '''
    This rule is specific to this project / dataset. It must be modified depending on the format
    of input metadata in order to get a list of libraries.
    '''
    input: h5=ancient(f"{data_dir}/CELLRANGER/{{libraryID}}/raw_feature_bc_matrix.h5")
    output: filtered_h5=f"{data_dir}/CELLBENDER/{{libraryID}}/output.h5"
    conda: 'envs/sysbio_singlecell'
    params:
        PAR_SLURM_ID=os.environ['SLURM_JOB_ID'],
        OUTDIR= f"{data_dir}/CELLBENDER/{{libraryID}}/"
    envmodules: 'cellbender/0.3.2'
    shell:
        '''
        #if [ -z ${{SLURM_JOB_ID:-}} ]; then export SLURM_JOB_ID={params.PAR_SLURM_ID}; fi; export TMPDIR=/lscratch/$SLURM_JOB_ID
        TMPDIR="LOCALTMP/{wildcards.libraryID}/"
        mkdir -p $TMPDIR && cd $TMPDIR
        TMP=$TMPDIR
        
        cellbender remove-background --cuda --input {input.h5} --output output.h5
        
        cp ./* {params.OUTDIR} && rm -rf $TMPDIR
        
        '''

rule build_ref_vcf:
    '''
    Builds reference VCF for use with dsc-pileup prior to freemuxlet
    '''
    output: f"{data_dir}/dsc-pileup-ref.vcf.gz"
    params:
        PAR_SLURM_ID=os.environ['SLURM_JOB_ID'],
        OUTDIR=data_dir
    shell:
        '''
        if [ -z ${{SLURM_JOB_ID:-}} ]; then export SLURM_JOB_ID={params.PAR_SLURM_ID}; fi; export TMPDIR=/lscratch/$SLURM_JOB_ID
        
        bash src/build-vcf-ref.sh {params.OUTDIR}
        '''

rule download_demux_vcf:
    '''
    retrieve pre-made VCF from cellsnp-lite team, hosted on sourceforge
    '''
    output: f"{data_dir}/DEMUX/genome1K.phase3.SNP_AF5e4.chr1toX.hg38.vcf.gz"
    shell:
        '''
        mkdir -p {data_dir}/DEMUX && cd {data_dir}/DEMUX
        wget https://sourceforge.net/projects/cellsnp/files/SNPlist/genome1K.phase3.SNP_AF5e4.chr1toX.hg38.vcf.gz
        '''

rule cellsnp_lite:
    '''
    generates pileup (required to run vireo), a more modern replacement for dsc-pileup
    '''
    input: bam=f"{data_dir}/CELLRANGER/{{libraryID}}/possorted_genome_bam.bam",
            barcodes=f"{data_dir}/CELLRANGER/{{libraryID}}/filtered_feature_bc_matrix/barcodes.tsv.gz",
            vcf=f"{data_dir}/DEMUX/genome1K.phase3.SNP_AF5e4.chr1toX.hg38.vcf.gz"
    output: f"{data_dir}/DEMUX/{{libraryID}}/cellSNP.cells.vcf.gz"
    envmodules: 'singularity/4.3.7'
    container: 'singularity/deconvolution/container.sif'
    threads: 10
    params:
        PAR_SLURM_ID=os.environ['SLURM_JOB_ID'],
        OUTDIR= f"{data_dir}/DEMUX/{{libraryID}}/"
    shell:
        '''
        if [ -z ${{SLURM_JOB_ID:-}} ]; then export SLURM_JOB_ID={params.PAR_SLURM_ID}; fi; export TMPDIR=/lscratch/$SLURM_JOB_ID
        cd $TMPDIR
        cellsnp-lite -s {input.bam} -b {input.barcodes} -O {params.OUTDIR} -R {input.vcf} -p {threads} --genotype --minMAF 0.1 --minCOUNT 20 --gzip
        mkdir -p {params.OUTDIR}
        cp cellSNP.* {params.OUTDIR}
        '''






# rule dsc_pileup:
#     '''
#     generates pileup (required to run freemuxlet)
#     '''
#     input: bam=f"{data_dir}/CELLRANGER/{{libraryID}}/possorted_genome_bam.bam",
#             vcf=f"{data_dir}/dsc-pileup-ref.vcf.gz"
#     output: f"{data_dir}/FREEMUXLET/{{libraryID}}/dsc-pileup.var"
#     envmodules:
#         'popscle/0.1_20210927'
#     params:
#         PAR_SLURM_ID=os.environ['SLURM_JOB_ID'],
#         OUTDIR= f"{data_dir}/FREEMUXLET/{{libraryID}}/"
#     shell:
#         '''
#         if [ -z ${{SLURM_JOB_ID:-}} ]; then export SLURM_JOB_ID={params.PAR_SLURM_ID}; fi; export TMPDIR=/lscratch/$SLURM_JOB_ID
#         cd $TMPDIR
#         popscle dsc-pileup --out dsc-pileup --vcf {input.vcf} --sam {input.bam}
#         mkdir -p {params.OUTDIR}
#         cp dsc-pileup* {params.OUTDIR}

#         '''
