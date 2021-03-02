const path = require("path");
const elmPath = path.resolve(__dirname, "./node_modules/.bin/elm");
const srcPath = path.resolve(__dirname, ".");

module.exports = () => {
  return {
    entry: "./index.js",
    output: {
      filename: "index.js",
      path: path.resolve(__dirname, "bundle"),
    },
    module: {
      noParse: /\.elm$/,
      rules: [
        {
          test: /\.elm$/,
          include: srcPath,
          exclude: [/elm-stuff/, /node_modules/],
          use: [
            {
              loader: require.resolve("elm-hot-webpack-loader"),
            },
            {
              loader: require.resolve("elm-webpack-loader"),
              options: {
                verbose: true,
                debug: true,
                pathToElm: elmPath,
                cwd: srcPath,
                forceWatch: true,
              },
            },
          ],
        },
        {
          test: /\.js$/,
          exclude: [/node_modules/],
          loader: "babel-loader",
        },
      ],
    },
    devServer: {
      contentBase: path.join(__dirname, "public"),
      port: 3030,
      publicPath: "http://localhost:3030/",
      hotOnly: true,
      host: "0.0.0.0",
      disableHostCheck: true,
    },
  };
};
