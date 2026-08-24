import { Controller } from "@hotwired/stimulus"

// Points the invitation link at the message built for whichever Sunday is picked. Every Sunday's message is
// rendered up front, so choosing one is only a matter of swapping the href.
export default class extends Controller {
    static targets = ["date", "link"]

    pick() {
        const option = this.dateTarget.selectedOptions[0]

        if (option) {
            this.linkTarget.href = option.dataset.href
        }
    }
}
