import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

let Hooks = {}

Hooks.Flash = {
    mounted() {
        let hide = () => window.liveSocket.execJS(this.el, this.el.getAttribute("phx-click"))
        this.timer = setTimeout(() => hide(), 5000)

        // Pause timer on hover
        this.el.addEventListener("mouseenter", () => clearTimeout(this.timer))
        this.el.addEventListener("mouseleave", () => {
            this.timer = setTimeout(() => hide(), 3000)
        })
    },
    destroyed() {
        clearTimeout(this.timer)
    }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: Hooks
})

liveSocket.connect()

window.liveSocket = liveSocket
