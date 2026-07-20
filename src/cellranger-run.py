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

project_dir = get_project_dir()                                 # Returns PosixPath object
configfile = project_dir / 'config.yaml'                 # Default config name within project_dir
config = import_config(configfile)                              # Loads as DotDict; exits if cannot load


#===================================================================================================
# 02 Pre-run Checks
#===================================================================================================
data_dir = require_path(project_dir / config.data_dir, label='data_dir', kind='dir', create=True)
library_id_file = require_path(data_dir / 'libraryIDs.txt', label='library_id_file', kind='file', create=False)



slurm_id = get_slurm_id()                                       # Exits if no SLURM_JOB_ID
slurm_array_id = get_slurm_array_id()                           # Exits if no SLURM_ARRAY_TASK_ID
temp_dir = require_path(f"{config.scratch}/{slurm_id}", label='temporary workign directory', kind='dir', create=True)              
check_write_access(temp_dir)                                    # Exits if not writable

require_command('cellranger')                                   # Exits if command not in PATH

transcriptome_dir = require_path(config.cellranger.transcriptome, label='Transcriptome', kind='dir', create=False)  # Exits if does not exist


#===================================================================================================
#  03 Build --libraries csv for running cellranger
#===================================================================================================
df = pd.read_csv(library_id_file, sep='\t')
library_id = df.loc[df['N'] == slurm_array_id, 'libraryID'].iloc[0]
output_dir = data_dir / 'CELLRANGER' / library_id


# use slurm_array_id to pull out Nth individual
cellranger_library_dir = require_path( data_dir / 'cellranger-library-files', label='cellranger_library_dir', kind='dir', create=True)
check_write_access(cellranger_library_dir)

# Generate cellranger --libraries csv file
library_csv = cellranger_library_dir / f"{library_id}.csv"

with open(library_csv, 'w') as outfile:
    outfile.write('fastqs,sample,library_type,\n')
    outfile.write(f"{data_dir},{library_id},{config.cellranger.assay},\n")

os.chdir(temp_dir)


if config.cellranger.tool == 'count':
    cmd = ['cellranger','count',
        '--id', library_id,
        '--create-bam', 'false',
        '--libraries', library_csv,
        '--output-dir', f"{library_id}_out",
        '--transcriptome', transcriptome_dir,
        '--chemistry', config.cellranger.chemistry,
        '--disable-cell-annotation',
        '--nosecondary']
    try:
        subprocess.run(cmd)
        # Copy outputs back to permanent dir after running
        shutil.copytree(src=f"{library_id}_out/outs",
                        dst=output_dir, 
                        dirs_exist_ok=True)
    except:
        sys.exit('ERROR: cellranger runtime error')
else:
    sys.exit(f"cellranger tool set to {config.cellranger.tool} but code undefined")
