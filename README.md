# Wordcloud

## Introduction

This visualization tool is to create your own word clouds and tag clouds. You can paste a long text and click on analyze button. Important word will be displayed in large size. The smaller word, the less important it is.

## Requirements

- Docker v20+

## Installation

1. Add following lines to file `/etc/hosts`

   ```
   127.0.0.1 www.wordcloud.io
   127.0.0.1 api.wordcloud.io
   ```

2. All environment values must be set

   ```
   CLIENT_HOST=wordcloud-client
   CLIENT_PORT=3030
   SERVER_HOST=wordcloud-server
   SERVER_PORT=5050
   MODE=development
   SERVE_LOCAL_HOST=0.0.0.0
   ```

   In production mode, change value of `MODE` to `production`

3. Run `docker-compose up`

4. Access http://www.wordcloud.io/

## Demo

<img src="https://via.placeholder.com/400x200/303030/FFFFFF/?text=demo"></img>
