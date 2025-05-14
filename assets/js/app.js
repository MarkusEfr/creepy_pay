import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "topbar"
import SendTx from "./hooks/send_tx.js"
import DismissBox from "./hooks/dismiss_box"


let Hooks = { SendTx, DismissBox }
Hooks.SendTx = SendTx
Hooks.DismissBox = DismissBox
Hooks.CopyLink = {
    mounted() {
        this.el.addEventListener("click", () => {
            const core = this.el.getAttribute("phx-value-core");
            const fullLink = `${window.location.origin}/pay/${core}`;
            navigator.clipboard.writeText(fullLink);
            this.el.innerText = "✅";
            setTimeout(() => (this.el.innerText = "🩸"), 1200);
        });
    }
};
Hooks.MerchantAuth = {
    mounted() {
        const token = localStorage.getItem("merchant_token");
        if (token) {
            this.pushEvent("auth_merchant_with_token", { token });
        }

        this.handleEvent("merchant_login_success", ({ token }) => {
            localStorage.setItem("merchant_token", token);
            window.location.href = "/merchant/dashboard";
        });
    }
};


let csrfToken = document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content")

let liveSocket = new LiveSocket("/live", Socket, {
    params: { _csrf_token: csrfToken },
    hooks: Hooks
})

topbar.config({ barColors: { 0: "#10b981" }, shadowColor: "rgba(0, 0, 0, .3)" })

window.addEventListener("phx:page-loading-start", () => topbar.show(300))
window.addEventListener("phx:page-loading-stop", () => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket
