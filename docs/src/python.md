## Use with Python
## MetopPy (Recommended)
A python wrapper around MetopDataset.jl. MetopPy can simply be installed using pip
```bash
pip install metoppy
```
Visit the [MetopPy repository](https://github.com/eumetsat/MetopPy) for more information and examples.

## Use with juliacall (Advanced)

This guide gives a basic example of using MetopDatasets in python via juliacall. For more information see [juliacall documentation](https://juliapy.github.io/PythonCall.jl/stable/juliacall/) for more information.

### Installation
The installation part just needs to be run once.
#### Prerequisites 
Julia, Python and Pip all needs to be installed on the machine. This can be checked with the following bash commands.
```bash
python --version
julia --version
pip --version
```
This guide is tested with the following versions 
- Python 3.12.8
- julia version 1.11.1
- pip 24.2
#### Installing python packages
We use pip to install `juliacall` and `numpy`. We need `juliacall` to interface with julia and `numpy` is just needed to demonstrate compatibility with numpy arrays.

```bash
pip install juliacall
pip install numpy
```

#### Installing MetopDatasets.jl
Install `MetopDatasets.jl` via `juliacall` by running the following Python code.
```python
import juliacall
# make separate module
jl = juliacall.newmodule("MetopDatasetsPy") 
jl.seval("import Pkg")
jl.Pkg.add("MetopDatasets")
```

### Example
You are now ready to use `MetopDatasets.jl` in python. Below are snippets of python code showing a simple example.
#### Loading MetopDatasets in the python session.
```python
import juliacall
import numpy as np
jl = juliacall.newmodule("MetopDatasetsPy")
jl.seval("using MetopDatasets")
```
#### Reading a dataset 
The dataset is simply read with `MetopDataset`. Only the metadata is read straight away. The variables can be read on demand.
```python
test_file = "/tcenas/home/lupemba/Documents/data/IASI_xxx_1C_M01_20240819103856Z_20240819104152Z_N_C_20240819112911Z"
ds = jl.MetopDataset(test_file, maskingvalue=float('nan'))
```
The dataset has a method equivalent to `__repr__` so the structure of the dataset can be shown easily. The julia `keys` function can be used to only list variable names.
```python
jl.keys(ds)
```
The individual variables can also be inspected. 
```python
ds["gs1cspect"]
```
The individual variables can be loaded and used like `np.arrays`. The record time is a small variable so we can load it all into memory.
```python
record_start_time = jl.Array(ds["record_start_time"])
print("record_start_time")
print(np.shape(record_start_time))
print(np.min(record_start_time))
print(np.max(record_start_time))
```

It is also possible to just load a slice of a variable. The size of the IASI spectra of an entire orbit is around 2 GB but we can easily load a subset into memory. 
```python
spectra_index = 2300
single_channel_slice = ds["gs1cspect"][spectra_index,:,:,0:10]
print("single_channel_slice")
print(np.shape(single_channel_slice))
print(np.mean(single_channel_slice))
```

## Alternative packages
For python alternatives see 
[Eugene](https://anaconda.org/Eumetsat/eugene) ([documentation](https://www-cdn.eumetsat.int/files/2020-04/pdf_ten_02030_ug_eugene.pdf)) or [Satpy](https://satpy.readthedocs.io/en/stable/index.html) (supports many EUMETSAT formats but only limited support for Metop). 