// assets/js/hooks/send_tx.js
import { ethers } from "ethers"

const SendTx = {
    async mounted() {
        const button = this.el.querySelector("button")
        button.addEventListener("click", async () => {
            const to = this.el.dataset.to
            const value = this.el.dataset.value
            const data = this.el.dataset.data || "0x"

            if (!window.ethereum) return alert("MetaMask not found!")

            const provider = new ethers.BrowserProvider(window.ethereum)
            const signer = await provider.getSigner()

            try {
                const tx = await signer.sendTransaction({
                    to,
                    value: BigInt(value),
                    data
                })

                console.log("TX sent:", tx.hash)
                this.pushEvent("tx_sent", { tx_hash: tx.hash })
            } catch (err) {
                console.error("Transaction failed", err)
                alert("Transaction failed: " + err.message)
            }
        })
    }
}

export default SendTx
