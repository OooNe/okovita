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
                // Find the first hidden input inside the sortable list
                let input = this.el.querySelector("input[type='hidden']")
                if (input) {
                    // Trigger input event natively on the hidden input so LiveView catches the change correctly
                    input.dispatchEvent(new Event("input", { bubbles: true }))
                } else {
                    // Fallback to form if no inputs exist yet
                    let form = this.el.closest("form")
                    if (form) {
                        form.dispatchEvent(new Event("input", { bubbles: true }))
                    }
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

Hooks.Multiselect = {
    mounted() {
        this.addButton = this.el.querySelector("[data-add]")
        this.search = this.el.querySelector("[data-search]")
        this.dropdown = this.el.querySelector("[data-dropdown]")
        this.hiddenSelect = this.el.querySelector("select[multiple]")

        this.addButton.addEventListener("click", () => {
            const isHidden = this.dropdown.classList.contains("hidden")
            if (isHidden) {
                this.openDropdown()
            } else {
                this.closeDropdown()
            }
        })

        // Filter options
        this.search.addEventListener("input", (e) => {
            let filter = e.target.value.toLowerCase()
            let items = this.dropdown.querySelectorAll("[data-option]")
            items.forEach(item => {
                let text = item.textContent.toLowerCase()
                if (text.includes(filter)) {
                    item.classList.remove("hidden")
                } else {
                    item.classList.add("hidden")
                }
            })
        })

        // Close on click away
        window.addEventListener("click", (e) => {
            if (!this.el.contains(e.target)) {
                this.closeDropdown()
            }
        })

        // Handle addition
        this.dropdown.addEventListener("click", (e) => {
            let option = e.target.closest("[data-option]")
            if (option) {
                this.toggleOption(option.dataset.id)
                this.search.value = ""
                // Reset filtering
                this.dropdown.querySelectorAll("[data-option]").forEach(i => i.classList.remove("hidden"))
                this.closeDropdown()
            }
        })

        // Handle removal via tags
        this.el.addEventListener("click", (e) => {
            let removeBtn = e.target.closest("[data-remove]")
            if (removeBtn) {
                this.toggleOption(removeBtn.dataset.id, false)
            }
        })

        // Accessibility/Navigation
        this.search.addEventListener("keydown", (e) => {
            if (e.key === "Escape") {
                this.closeDropdown()
            }
        })
    },

    openDropdown() {
        // Remove any previous positioning
        this.dropdown.style.top = ""
        this.dropdown.style.bottom = ""
        this.dropdown.classList.remove("hidden")

        // Measure available space below the button
        const buttonRect = this.addButton.getBoundingClientRect()
        const dropdownHeight = this.dropdown.offsetHeight
        const viewportHeight = window.innerHeight
        const spaceBelow = viewportHeight - buttonRect.bottom
        const spaceAbove = buttonRect.top

        // Flip above if not enough space below (need at least dropdownHeight + 8px margin)
        if (spaceBelow < dropdownHeight + 8 && spaceAbove > spaceBelow) {
            // Position above the container
            const containerRect = this.el.getBoundingClientRect()
            const containerBottom = this.el.offsetHeight
            this.dropdown.style.top = "auto"
            this.dropdown.style.bottom = `${containerBottom}px`
        } else {
            this.dropdown.style.top = ""
            this.dropdown.style.bottom = ""
        }

        this.search.focus()
    },

    closeDropdown() {
        this.dropdown.classList.add("hidden")
        this.dropdown.style.top = ""
        this.dropdown.style.bottom = ""
        this.search.value = ""
        this.dropdown.querySelectorAll("[data-option]").forEach(i => i.classList.remove("hidden"))
    },

    toggleOption(id, shouldSelect = null) {
        let option = Array.from(this.hiddenSelect.options).find(opt => opt.value === id)
        if (option) {
            const newState = shouldSelect === null ? !option.selected : shouldSelect
            if (option.selected !== newState) {
                option.selected = newState
                this.hiddenSelect.dispatchEvent(new Event("change", { bubbles: true }))
                this.hiddenSelect.dispatchEvent(new Event("input", { bubbles: true }))
            }
        }
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

import { Hooks as CkeditorHooks } from "ckeditor5_phoenix"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: { ...Hooks, ...CkeditorHooks }
})

liveSocket.connect()

window.liveSocket = liveSocket
