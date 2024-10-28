# Settings

To run the jupyter notebooks, we suggest you to use [Anaconda](https://www.anaconda.com/). Open the terminal into the repository and type the following commands:

- conda create -n *env_name* pip python=3.12
- conda activate *env_name*
- pip install -r requirements.txt
- jupyter notebook
- conda deactivate
- conda env remove -n *env_name*

In case you are using Python installed on your laptop, you can create a virtual environment with the following commands:

- python -m venv *env_name*
- **For mac0S/Linux:** source *env_name*/bin/activate
- **For Windows:** *env_name*\Scripts\activate
- pip install -r requirements.txt
- jupyter notebook
- **For mac0S/Linux:** source bin/deactivate
- **For Windows:** scripts\deactivate
