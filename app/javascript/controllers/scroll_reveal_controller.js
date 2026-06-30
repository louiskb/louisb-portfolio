import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="scroll-reveal"
// Watches the element with IntersectionObserver and adds .reveal-visible to
// reveal targets when the section enters the viewport. CSS handles the actual
// animation (and is gated behind prefers-reduced-motion, so reduced-motion
// users see the content immediately).
//
// Targets:
//   fromLeft   — slides in from left (staggered when multiple)
//   fromRight  — slides in from right
//   fadeIn     — simple opacity fade
//   fromBottom — slides up from below (staggered when multiple)
export default class extends Controller {
  static targets = ["fromLeft", "fromRight", "fadeIn", "fromBottom"];

  connect() {
    this._observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          // Staggered left-to-right
          this.fromLeftTargets.forEach((el, i) => {
            setTimeout(() => el.classList.add("reveal-visible"), i * 120);
          });
          // Simultaneous
          this.fromRightTargets.forEach((el) =>
            el.classList.add("reveal-visible")
          );
          this.fadeInTargets.forEach((el) =>
            el.classList.add("reveal-visible")
          );
          // Staggered bottom-to-top
          this.fromBottomTargets.forEach((el, i) => {
            setTimeout(() => el.classList.add("reveal-visible"), i * 100);
          });
          this._observer.disconnect(); // animate once only
        });
      },
      { threshold: 0.1 }
    );
    this._observer.observe(this.element);
  }

  disconnect() {
    this._observer?.disconnect();
  }
}
