import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="clipboard"
export default class extends Controller {
  static targets = ["shareButton", "source"];

  copy(event) {
    // Belt-and-braces: the trigger is a <button type="button"> so there is no
    // navigation to cancel, but preventDefault keeps this action safe if it is
    // ever wired to a link again (an href="#" would scroll-jump to the top).
    event.preventDefault();
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
