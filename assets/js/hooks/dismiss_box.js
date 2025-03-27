const DismissBox = {
    mounted() {
        setTimeout(() => {
            this.el?.remove()
        }, 8000)
    }
}

export default DismissBox
