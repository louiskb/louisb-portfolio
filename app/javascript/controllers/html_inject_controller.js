import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="html-inject"
export default class extends Controller {
  connect() {
    console.log("html_inject connected!");
    this.element.removeAttribute("hidden");
    // Any logic in connect() runs automatically on DOM connection.
  }
}
