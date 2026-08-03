import { Controller } from "@hotwired/stimulus"

// Navigates to a pre-built filter URL when a control (e.g. a checkbox) toggles,
// mirroring the behavior of clicking a filter dropdown link.
export default class extends Controller {
    static values = { url: String }

    toggle() {
        Turbo.visit(this.urlValue, { action: "advance" })
    }
}
