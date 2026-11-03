import {Controller} from "@hotwired/stimulus"

export default class extends Controller {

    connect() {
        const form = this.element

        Array.from(form).forEach(function (el) {
            el.addEventListener("input", function () {
                // requestSubmit, not submit: it fires the submit event, so Turbo
                // handles the navigation instead of the browser tearing the
                // document down and reloading it.
                form.requestSubmit()
            })
        })
    }
}
