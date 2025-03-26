import { Socket } from "phoenix"
import LiveSocket from "phoenix_live_view"
import topbar from "../vendor/topbar"
import SendTx from "./hooks/send_tx"

let Hooks = { SendTx }

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
    hooks: Hooks,
    params: { _csrf_token: csrfToken }
})

// connect if LiveView is on the page
liveSocket.connect()

window.liveSocket = liveSocket

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })