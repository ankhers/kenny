// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"

import socket from "./socket"

let status = document.getElementById("status");
let start = document.getElementById("start");
start.disabled = true;

let channel = socket.channel("game:stationeers", {});
channel.join()
  .receive("ok", resp => {
    status.innerHTML = resp.status;

    if (resp.status == "up") {
      status.innerHTML = status.innerHTML + " " + resp.n;
      start.disabled = true;
    } else {
      start.disabled = false;
    }
  })
  .receive("error", resp => console.log("Unable to join", resp));

start.addEventListener('click', event => {
  channel.push('start_server', {})
    .receive("ok", resp => {
      start.disabled = true;
    });
});

channel.on('update_status', payload => {
  status.innerHTML = payload.status;

  if (payload.status == 'up') {
    status.innerHTML = status.innerHTML + " " + payload.n;
    start.disabled = true;
  } else {
    start.disabled = false;
  }
});
