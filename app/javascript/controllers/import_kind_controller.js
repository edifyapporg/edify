import {Controller} from "@hotwired/stimulus"

// Shows the paste field for each tab the chosen import reads, and holds the Import button back until a choice is made.
// Without JavaScript every field shows and the server refuses a submit with no choice.
export default class extends Controller {

    static targets = ["option", "field", "submit"]

    connect() {
        this.select()
    }

    select() {
        const kind = this.selectedKind()

        this.fieldTargets.forEach(function (field) {
            const shown = kind !== null && field.dataset.kinds.split(" ").includes(kind)
            field.classList.toggle("d-none", !shown)
            field.querySelectorAll("textarea").forEach(textarea => textarea.disabled = !shown)
        })

        this.submitTarget.disabled = kind === null
    }

    selectedKind() {
        const checked = this.optionTargets.find(option => option.checked)
        return checked ? checked.value : null
    }
}
