import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="html-inject"
export default class extends Controller {
  connect() {
    console.log("html_inject stimulus controller connected!")
  }

  convertHtmlString(event) {
    console.log(event);
    // Store textContent of <article> into a variable.
    // Add it as adjacentHTML "beforeend".
    // Remove textContent of <article>.
    // Remove hidden boolean attribute from <article>.
    
  }
}
