import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import Sortable from "sortablejs"

let Hooks = {}

Hooks.Sortable = {
    mounted() {
        this.sortable = new Sortable(this.el, {
            animation: 150,
            ghostClass: "opacity-50",
            onEnd: (e) => {
                let form = this.el.closest("form")
                if (form) {
                    // Trigger input event to simulate form change so LiveView updates its state
                    form.dispatchEvent(new Event("input", { bubbles: true }))
                }
            }
        })
    },
    destroyed() {
        this.sortable.destroy()
    }
}

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

const SAFE_METHODS = ["focus", "blur", "click", "reset", "submit"]

window.addEventListener("phx:js-exec", (e) => {
    if (SAFE_METHODS.includes(e.detail.attr)) {
        document.querySelectorAll(e.detail.to).forEach(el => {
            if (typeof el[e.detail.attr] === "function") {
                el[e.detail.attr]()
            }
        })
    } else {
        console.warn("Zablokowano potencjalnie niebezpieczne wykonanie js-exec:", e.detail.attr)
    }
})

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: Hooks
})

liveSocket.connect()

window.liveSocket = liveSocket
