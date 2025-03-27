import { ethers } from "ethers"

const SendTx = {
    async mounted() {
        const button = this.el.querySelector("button")

        button.addEventListener("click", async () => {
            try {
                const paymentRaw = this.el.dataset.payment
                const to = this.el.dataset.contract

                const payment = JSON.parse(paymentRaw)
                const invoice = payment.invoice_details

                if (!window.ethereum) {
                    alert("Web3 provider not found in browser!")
                    return
                }

                const provider = new ethers.BrowserProvider(window.ethereum)
                const signer = await provider.getSigner()

                const tx = {
                    to,
                    value: BigInt(payment.amount),
                    data: invoice.data
                }

                try {
                    const gasEstimate = await signer.estimateGas(tx)
                    tx.gasLimit = gasEstimate
                } catch (err) {
                    console.warn("⚠️ estimateGas failed, fallback to hardcoded gas")
                    tx.gasLimit = ethers.toBigInt("100000")
                }

                const sentTx = await signer.sendTransaction(tx)

                this.pushEvent("tx_sent", { tx_hash: sentTx.hash })

            } catch (err) {
                const fallbackReason =
                    err.reason ||
                    (err.error && err.error.reason) ||
                    (err.revert && err.revert.args && err.revert.args[0]) ||
                    err.message

                this.pushEvent("tx_failed", {
                    reason: fallbackReason
                })
            }
        })
    }
}

export default SendTx
