# Server

## Requirements

- Python 3.6.10

### Set up server alone

1. Enter virtual environment

   Create virtual environment if not be done yet

   ```
   virtualenv app-env
   ```

   Enter the created env

   ```
   source app-env/bin/activate
   ```

2. Install python packages

   ```
   pip3 install -r requirements.txt

   ```

3. Setup enviroments. It can be the same as docker setup environments

4. Start application

   ```
   python app.py
   ```

5. You can install Postman to establish POST connection to http://0.0.0.0:5050

## Tests

Run ...

## Topics

1. CORS origin issue

   If running Wordcloud app with Docker compose, server will run at subdoman `api.wordcloud.io`. This can cause error to any request from client host `www.wordcloud.io`. To avoid this, we will let server app allow CORS on client domain.

2. Develop with Jupyter

   You can develop on Jupyter. To covert to a Jupyter note book to python file, run command

   ```
   ipynb-py-convert app.ipynb build/app.py
   ```

3. Update file requirements

   In case that you need install a new python lib, to store this installation to requirement file, run command

   ```
   pip3 freeze > requirements.txt
   ```

4. Server app could incidentally stop durning development. Run this command to restart the app
   ```
   docker restart wordcloud-server
   ```
