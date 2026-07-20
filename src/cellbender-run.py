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
step = 'cellbender'
config.step = config[step]

#===================================================================================================
# 02 Pre-run Checks
#===================================================================================================
data_dir = require_path(project_dir / config.data_dir, label='data_dir', kind='dir', create=True)
library_id_file = require_path(data_dir / 'libraryIDs.txt', label='library_id_file', kind='file', create=False)



slurm_id = get_slurm_id()                                       # Exits if no SLURM_JOB_ID
slurm_array_id = get_slurm_array_id()                           # Exits if no SLURM_ARRAY_TASK_ID
temp_dir = require_path(f"{config.scratch}/{slurm_id}", label='temporary workign directory', kind='dir', create=True)              
check_write_access(temp_dir)                                    # Exits if not writable
require_command('cellbender')                                   # Exits if command not in PATH


#===================================================================================================
#  03 Build --libraries csv for running cellbender
#===================================================================================================
df = pd.read_csv(library_id_file, sep='\t')
library_id = df.loc[df['N'] == slurm_array_id, 'libraryID'].iloc[0]

input_h5 = require_path(path=data_dir / 'CELLRANGER' / library_id / 'raw_feature_bc_matrix.h5', label='cellranger h5', kind='file', create=False)
output_h5 = data_dir / 'CELLBENDER' / f'{library_id}.h5'
check_write_access(output_h5.parent)

os.chdir(temp_dir)


cmd = ['cellbender','remove-background', '--cuda',
       '--input', input_h5,
       '--output', output_h5]

try:
    subprocess.run(cmd)
    # # Copy outputs back to permanent dir after running
    # shutil.copytree(src=f"{library_id}_out/outs",
    #                 dst=output_dir, 
    #                 dirs_exist_ok=True)
except:
    print('Error while running cellbender')
    raise 
