import { Controller } from "@hotwired/stimulus"

// Handles the blog index search bar + tag filter pills.
// Auto-submits the GET form when a tag pill is toggled.
// Debounces the search input so it doesn't fire on every keypress.
// (Analytics is intentionally absent here — it lands in Phase 5.)
export default class extends Controller {
  connect() {
    this._searchTimer = null
  }

  disconnect() {
    clearTimeout(this._searchTimer)
  }

  // Called by data-action="input->blog-filter#search" on the search input.
  search() {
    clearTimeout(this._searchTimer)
    this._searchTimer = setTimeout(() => {
      this.element.requestSubmit()
    }, 400)
  }

  // Called by data-action="change->blog-filter#submit" on tag checkboxes.
  submit() {
    this.element.requestSubmit()
  }
}
