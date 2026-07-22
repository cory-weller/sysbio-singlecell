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
configfile: project_dir / 'config.yaml'                 # Default config name within project_dir
#config = import_config(configfile)                              # Loads as DotDict; exits if cannot load

print(config)

config = DotDict(config)

data_dir = project_dir / config.data_dir
synapse_metadata_summary = data_dir / config.synapse.metadata_summary

localrules: get_metadata, download_data, prep_cellranger

# ── Rules ──────────────────────────────────────────────────────
rule all:
    input: f"{data_dir}/download_data.done", data_dir / 'libraryIDs.txt'

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
        python3 -u src/01_get_metadata.py
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
    conda: 'envs/sysbio_singlecell.yaml'
    shell:
        """
        python3 -u src/02_file_download.py
        touch {output}
        """

rule prep_cellranger:
    output: libmap = str(data_dir / 'libraryIDs.txt')
    conda: 'envs/sysbio_singlecell.yaml'
    run:
        # generate library ID file if it does not exist
        print(output.libmap)
        library_id_file = Path(output.libmap)
        library_metadata_file = find_file(config.metadata.sample_libraries)
        if not library_id_file.exists():
            dat = pd.read_csv(library_metadata_file)['libraryBatch'].unique()
            df = pd.DataFrame({
                'N': range(1, len(dat)+1),
                'libraryID': [x+'-GEX' for x in dat]
            })
            df.to_csv(library_id_file, index=False, sep='\t')
        else:
            pass

# rule cellranger:
#     input: data_dir / 'libraryIDs.txt'
#     output: data_dir/CELLRANGER/{libraryID}/
#     conda: 'envs/sysbio_singlecell.yaml'
#     resources:
#         slurm_partition: config.cellranger.slurm.partition
#         runtime:    config.cellranger.slurm.walltime
        
#     envmodules:
#         - cellranger/10.1.0
#     shell:
#         """
#         python3 -u src/03_cellranger_submit.py
#         touch {output}
#         """