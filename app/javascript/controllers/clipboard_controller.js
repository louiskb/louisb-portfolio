import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="clipboard"
export default class extends Controller {
  static targets = ["shareButton", "source"];

  connect() {
    console.log("clipboard controller connected!");
  }

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value);
    const button = this.shareButtonTarget;
    const originalHTML = button.innerHTML;
    button.innerText = "Link Copied!";
    setTimeout(() => {
      button.innerHTML = originalHTML;
    }, 2000); // schedules a one-time execution of the arrow function after a 2000-millisecond (2-second) delay, restoring the button's saved original text after a "Copied!" feedback message.
    // `setTimeout(callback, delay)` queues the callback function to run asynchronously once the delay elapses, without blocking other code.
  }
}
