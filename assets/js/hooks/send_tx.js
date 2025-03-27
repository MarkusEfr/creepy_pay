import { ethers } from "ethers"

const SendTx = {
    async mounted() {
        const button = this.el.querySelector("button")

        button.addEventListener("click", async () => {
            const to = this.el.dataset.to
            const value = this.el.dataset.value
            const data = this.el.dataset.data || "0x"

            if (!window.ethereum) {
                alert("Web3 provider not found in browser!")
                return
            }

            const provider = new ethers.BrowserProvider(window.ethereum)
            const signer = await provider.getSigner()

            try {
                const tx = {
                    to,
                    value: ethers.toBigInt(value),
                    data
                }

                // 👻 Optional safety: simulate before sending
                await signer.estimateGas(tx)

                const sentTx = await signer.sendTransaction(tx)

                console.log("TX sent:", sentTx.hash)
                this.pushEvent("tx_sent", { tx_hash: sentTx.hash })

            } catch (err) {
                const fallbackReason =
                    err.reason ||
                    (err.error && err.error.reason) ||
                    (err.revert && err.revert.args && err.revert.args[0]) ||
                    err.message

                console.error("Transaction failed:", err)

                alert(
                    `Transaction failed!\n\nReason: ${fallbackReason || "Unknown"}\n\nDetails:\n` +
                    JSON.stringify(err, null, 2)
                )

                this.pushEvent("tx_failed", { reason: fallbackReason })
            }
        })
    }
}

export default SendTx
