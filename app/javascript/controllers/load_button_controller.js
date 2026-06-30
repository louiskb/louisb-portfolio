import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="load-button"
//
// Two usage modes:
//   1. data-action="click->load-button#loader"       → show a spinner AND submit
//      the form (used by the contact form's single submit button).
//   2. data-action="click->load-button#showSpinner"  → show a spinner only;
//      another controller (e.g. publish-form) submits the form after it sets
//      the hidden status/scheduled_at fields.
//
// Mark the button group wrapper with data-load-button-target="buttons" so the
// spinner replaces it; optional per-button text via
// data-load-button-loading-text-value="Publishing...".
export default class extends Controller {
  static targets = ["buttons"];
  static values = { loadingText: { type: String, default: "Sending..." } };

  connect() {
    console.log("load_button connected!");
  }

  // Original behaviour: append a spinner inside the form and submit it.
  // `this.element` is the form DOM element with data-controller="load-button".
  loader(event) {
    const form = this.element;
    form.insertAdjacentHTML(
      "beforeend",
      '<div class="btn btn-primary btn-lg rounded-5 mb-4 mt-4 disabled"><i class="fa-solid fa-spinner fa-spin"></i> Sending...</div>'
    ); // Single quotes here because HTML attribute values use double quotes.
    event.currentTarget.remove(); // Removes the clicked button.
    form.requestSubmit(); // Programmatically submits the form (built-in DOM method).
  }

  // Hide the button group and show a spinner WITHOUT submitting — used when
  // another controller (publish-form) handles submission.
  showSpinner(event) {
    this._showSpinner(event);
  }

  _showSpinner(event) {
    const text =
      event?.currentTarget?.dataset?.loadButtonLoadingTextValue ||
      this.loadingTextValue;

    // Inherit the triggering button's visual classes so the spinner matches.
    // Strip structural/split-button classes, dropdown-item, and spacing/rounding
    // utilities that don't belong on a static span. If stripping leaves nothing
    // (e.g. a bare dropdown-item click), fall back to the primary button style.
    const STRIP =
      /\b(dropdown-toggle-split|dropdown-toggle|dropdown-item|rounded-\S+|[mp][trblxy]?-\d+)\b/g;
    const stripped = event?.currentTarget
      ? event.currentTarget.className.replace(STRIP, "").replace(/\s+/g, " ").trim()
      : "";
    const btnClasses = stripped || "btn btn-primary";

    const spinner = `<div class="mt-4 mb-4"><span class="${btnClasses}" style="pointer-events:none;cursor:default"><i class="fa-solid fa-hourglass fa-spin me-1"></i> ${text}</span></div>`;

    if (this.hasButtonsTarget) {
      this.buttonsTarget.classList.add("d-none");
      this.buttonsTarget.insertAdjacentHTML("afterend", spinner);
    } else {
      this.element.insertAdjacentHTML("beforeend", spinner);
    }
  }
}
