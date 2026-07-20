#!/usr/bin/env python3
# coding: utf-8

# # 01_get_metadata

# In[ ]:


# Imports
import synapseclient
import os
import sys
import yaml
from pathlib import Path
import asyncio
import pickle
from textwrap import dedent

from synapseclient.models import (
    File, Folder, Project, Table, EntityView, Dataset,
    DatasetCollection, MaterializedView, SubmissionView, VirtualTable
)

def get_project_dir():
    # Automatically determine project directory
    try:
        project_dir = Path(__file__).resolve().parent
        text = dedent(f"""\
                    INFO:\tProject Directory automatically determined from script location
                    \tScript:\t{__file__}
                    \tDir:\t{project_dir}\
                    """)
        print(text)
    except NameError:
        project_dir = os.getcwd()
        text = dedent(f"""\
                    INFO:\tsetting Project Direcetory to current working directory for interactive execution
                    \t Dir: {os.getcwd()}\
                    """)
        print(text)


def write_mdata(mdata, fn):
    header = [x[0] for x in mdata[0]]
    values = []
    for x in mdata:
        values.append([i[1] for i in x])
    os.makedirs(Path(fn).parent, exist_ok=True)
    with open(fn, 'w') as outfile:
        outfile.write('\t'.join(header) + '\n')     # Write first half of tuple as header
        for v in values:
            outfile.write('\t'.join(v) + '\n')     # Write second half of tuple as values

def format_property(p):
    o = {}
    for key,value in p.items():
        if not isinstance(value, list):
            o[key] = str(value)
        if isinstance(value, list):
            o[key] = ';'.join([str(x) for x in value])
    return(o)

def update_files(synfolder, filetree='.'):
    # Update each file in the current node
    for synfile in synfolder.files:
        synfile.file_name = f"{filetree}/{synfile.file_handle.file_name}"
    # Recurse into nested folders
    for folder in synfolder.folders:
        update_files(folder, f"{filetree}/{folder.id}")

# def get_files(synfolder):
#     for synfile in synfolder.files:
#         yield synfile
#     for folder in synfolder.folders:
#         yield from get_files(folder)

def get_items(_dict, _keys):
    items = []
    for key in _keys:
        if key in _dict:
            items.append((key, _dict[key]))
        else:
            items.append((key, 'N/A'))
    return(items)

def extract_mdata(SYNFILE):
    file_handle_order = ['id',
                    'etag',
                    'created_by',
                    'created_on',
                    'modified_on',
                    'concrete_type',
                    'content_type',
                    'content_md5',
                    'storage_location_id',
                    'content_size',
                    'status',
                    'bucket_name',
                    'key',
                    'preview_id',
                    'is_preview',
                    'external_url']
    annotations_order = ['sex',
                        'assay',
                        'grant',
                        'organ',
                        'study',
                        'tissue',
                        'runType',
                        'species',
                        'cellType',
                        'dataType',
                        'platform',
                        'consortium',
                        'fileFormat',
                        'readLength',
                        'specimenID',
                        'dataSubtype',
                        'libraryPrep',
                        'individualID',
                        'resourceType',
                        'isModelSystem',
                        'isMultiSpecimen',
                        'nucleicAcidSource',
                        'individualIdSource']
    metadata = []
    synid = SYNFILE.id
    metadata =  [('synid',synid)]
    metadata += [('file_name', SYNFILE.file_name)]
    metadata += [('version_label', SYNFILE.version_label)]
    metadata += get_items(format_property(SYNFILE.file_handle.__dict__), file_handle_order)
    metadata += get_items(format_property(SYNFILE.annotations), annotations_order)
    return(metadata)


async def get_files(synid, syn):
    empty_entity = await syn.get_async(synid, download_file=False)
    if empty_entity.concreteType == 'org.sagebionetworks.repo.model.FileEntity':  # is File
        entity = await File(id=synid, download_file=False).get_async()    # Single file object with metadata
        entity.file_name = entity.id + '/' + entity.file_handle.file_name
        return([entity])
    elif empty_entity.concreteType == 'org.sagebionetworks.repo.model.Folder':     # is Folder
        entity = Folder(id=synid)
        entity = await entity.sync_from_synapse_async(download_file=False)       # Folder with list of file objects
        update_files(entity, entity.id)
        return(flatten_files(entity))

def flatten_files(node):
    files = []
    if node.files is not None:
        files += (node.files)
    for folder in node.folders:
        files += flatten_files(folder)
    return files


async def main():
    # Load config from yaml file
    with open("config.yaml") as f:
        config = yaml.safe_load(f)

    config


    # Check if final output exists:
    metadata_output = config['data_dir'] + '/' + config['file_metadata']
    if os.path.exists(metadata_output):
        if config['clobber']:
            print(f"Final output {metadata_output} exists, but re-running anyway because clobber=True")
        else:
            raise SystemExit(f"Final output {metadata_output} exists, stopping because clobber=False")


    # Authenticate to synapse
    with open(os.path.expanduser(config['token']), 'r') as f:
        token = f.read().strip()


    syn = synapseclient.login(authToken=token)


    # Recursively syncfolder data

    config_datasets = config['datasets']

    if isinstance(config_datasets, str):
        datasets_ids = [config_datasets]
    else:
        datasets_ids = config_datasets

    config_datasets


    print(datasets_ids)

    combined_metadata = []
    for synapse_id in datasets_ids:
        mdata = await get_files(synapse_id, syn)
        combined_metadata += [extract_mdata(x) for x in mdata]


    with open("combined_metadata.pkl", "wb") as file:
        pickle.dump(combined_metadata, file)

    # Write to final metadata file for sequencing reads to output
    write_mdata(combined_metadata, metadata_output)




if __name__ == "__main__":
    asyncio.run(main())