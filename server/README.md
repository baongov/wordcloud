Virtual env
source app-env/bin/activate

Code with Jupyter

Update file requirements

# covert to python file 
ipynb-py-convert app.ipynb build/app.py

# Develop mode
docker restart wordcloud-server

# Production mode

# CORS origin issue
