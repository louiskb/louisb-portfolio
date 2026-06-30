import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      ghostClass: "sortable-ghost",
      handle: ".drag-handle",
      onEnd: () => this.#saveOrder()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  #saveOrder() {
    const ids = Array.from(this.element.children).map(el => el.dataset.id)

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      },
      body: JSON.stringify({ ids })
    })
  }
}
