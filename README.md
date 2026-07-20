# Run notebook
Note: First activate conda environment that contains `asyncio`, `synapseclient`, `pandas`, etc.

```bash
# note book version
#jupyter nbconvert --to notebook --execute 01_get_metadata.ipynb --output 01_result.ipynb

# python version
python3 01_get_metadata.py
```

```bash
# notebook version
# jupyter nbconvert --to notebook --execute 02_file_download.ipynb --output 02_result.ipynb

# python version
python3 02_file_download.py
```

```bash
# Run without any special environment
python3 03_submit_cellranger.py
```