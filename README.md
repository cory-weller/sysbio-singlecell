# Run notebook
Note: First activate conda environment that contains `asyncio`, `synapseclient`, `pandas`, etc.

```bash
# note book version
#jupyter nbconvert --to notebook --execute 01_get_metadata.ipynb --output 01_result.ipynb

# python version
python3 01_get_metadata.py
python3 02_file_download.py
python3 03_cellranger_submit.py
python3 04_cellbender_submit.py
```
