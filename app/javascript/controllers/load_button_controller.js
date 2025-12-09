import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="load-button"
export default class extends Controller {

  connect() {
    console.log("load_button connected!");
  }

  loader(event) {
    console.log(event); // Logs the full event object for debugging (shows target, currentTarget, etc.)
    const form = this.element; // `this.element` is the form DOM element with data-controller="load-button" attribute.
    form.insertAdjacentHTML(
      "beforeend",
      '<div class="btn btn-primary btn-lg rounded-5 mb-4 mt-4 disabled"><i class="fa-solid fa-spinner fa-spin"></i> Sending...</div>'
    ); // Appends a spinning loader button inside the form - "beforeend" so the last child element of the form just where the submit button is supposed to be.
    // Also, notice in this case, single quotations are used instead of double quotations because HTML attribute values use double quotations and this works fine for HTML-in-JS. Template literals with (backticks) `` instead of single quotes '' works just as good too.
    event.currentTarget.remove(); // Removes the clicked button (event.currentTarget = element with data-action="click->load-button#loader")
    form.requestSubmit(); // Programmatically submits the form, triggering validation + Turbo/Rails handling. `requestSubmit()` works on the form element not the submit button.
    // FYI `remove()` and `requestSubmit()` are built-in JavaScript DOM methods available natively in modern browsers.
  }
}
