import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js";

export default class extends Controller {

  static values = {
    date: String,
  }

  update() {
    const url = "/unit/speaker_last_spoke"

    get(url, {
      query: {
        date: this.dateValue,
        name: this.element.value,
      },
      responseKind: "turbo-stream"
    })
  }
}
