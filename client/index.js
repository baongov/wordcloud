import { Elm } from "./src/App.elm";

window.addEventListener("load", () => {
  const node = document.getElementById("app");
  try {
    Elm.App.init({ node, flags: {serverHost: "http://api.wordcloud.io"} });
  } catch (e) {
    console.log(e);
  }
});
