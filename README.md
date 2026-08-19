# Run notebook
Note: First activate conda environment that contains `asyncio`, `synapseclient`, `pandas`, etc.

```bash
# note book version
#jupyter nbconvert --to notebook --execute 01_get_metadata.ipynb --output 01_result.ipynb

# python version
python3 src/01_get_metadata.py
python3 src/02_file_download.py
python3 src/03_cellranger_submit.py
python3 src/04_cellbender_submit.py
```
# 
```bash
wget https://github.com/brentp/somalier/files/4566475/sites.hg38.rna.vcf.gz
# ad0e523b19164b9af4dda86c90462f6a  sites.hg38.rna.vcf.gz

```
## Cellbender
Failed sample:
- `VR297-GEX` : Not enough cells. There were an estimated 2176 after cellranger
