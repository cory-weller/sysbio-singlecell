#!/usr/bin/env python3
# coding: utf-8


# Imports
import synapseclient
import os
import sys
import yaml
from pathlib import Path
import pandas as pd
import hashlib
import asyncio


def get_md5(filename):
    hash_md5 = hashlib.md5()
    with open(filename, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


async def main():

    pwd = Path(os.getcwd())
    pwd

    # Load config from yaml file
    with open("config.yaml") as f:
        config = yaml.safe_load(f)

    config




    # Authenticate to synapse
    with open(os.path.expanduser(config['token']), 'r') as f:
        token = f.read().strip()
        
    syn = synapseclient.login(authToken=token)


    # Import reads metadata file
    metadata_filename = config['data_dir'] + '/' + config['file_metadata']
    df = pd.read_csv(metadata_filename, sep='\t')


    bad_files = []
    good_files = []
    retries = []        # Tuple (synid, filepath, version, meta_md5)

    # FIRST check of files
    # iterate over rows of metadata:
    for i in range(df.shape[0]):
        x = df.iloc[i]
        filepath = Path('DATA/' + x['file_name'])
        synid = x['synid']
        version = int(x['version_label'])
        meta_md5 = x['content_md5']
        
        # Download file if it does not exist
        if not os.path.exists(filepath):
            await syn.get_async(synid, download_file=True,
                            downloadLocation=filepath.parent,
                            if_collision="overwrite.local",
                            synapse_client=syn)
        
        # Calculate md5 if it does not exist
        if not os.path.exists(f"{filepath}.md5"):
            file_md5 = get_md5(f"{filepath}")
        else:
            with open(f"{filepath}.md5", 'r') as infile:
                file_md5 = infile.read().strip()
        
        # Compare md5
        if file_md5 != meta_md5:
            print(f"{synid} Local file md5 ({file_md5}) does not match metadata md5 ({meta_md5}) for file {filepath} version {version}!")
            print(f"Removing file {filepath} and retrying")
            os.remove(filepath)
            os.remove(f"{filepath}.md5")
            retries.append((synid, filepath, version, meta_md5))
        
        # Only written if file md5 matches metadata md5
        elif file_md5 == meta_md5:
            good_files.append((synid, filepath, version, meta_md5))
            with open(f"{filepath}.md5", 'w') as outfile:
                outfile.write(file_md5 + '\n')


    retries



    # Retries:
    # iterate over rows of metadata:
    for synid, filepath, version, meta_md5 in retries:
        
        # Download file
        await syn.get_async(synid, download_file=True,
                        downloadLocation=filepath.parent,
                        if_collision="overwrite.local",
                        synapse_client=syn)
        
        # Calculate md5
        file_md5 = get_md5(f"{filepath}")
        
        # Compare md5
        if file_md5 != meta_md5:
            print(f"{synid} Local file md5 ({file_md5}) still does not match metadata md5 ({meta_md5}) for file {filepath} version {version}!")
            print(f"Removing files and NOT retrying")
            os.remove(filepath)
            os.remove(f"{filepath}.md5")
            bad_files.append((synid, filepath, version, meta_md5))
        
        # Only written if file md5 matches metadata md5
        elif file_md5 == meta_md5:
            good_files.append((synid, filepath, version, meta_md5))
            with open(f"{filepath}.md5", 'w') as outfile:
                outfile.write(file_md5 + '\n')


    good_files



    bad_files

    # Test if every file in metadata passed md5 check
    print(df.shape[0] == len(good_files))

if __name__ == "__main__":
    asyncio.run(main())