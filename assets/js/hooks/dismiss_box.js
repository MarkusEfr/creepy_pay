const DismissBox = {
    mounted() {
        const el = this.el
        const closeBtn = el.querySelector(".close-error")

        if (closeBtn) {
            closeBtn.addEventListener("click", () => {
                el.remove()
            })
        }

        setTimeout(() => {
            el.classList.add("fade-out")
            setTimeout(() => el.remove(), 300)
        }, 12000)

    }
}

export default DismissBox
