import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="count-up"
// On first scroll into view, animates the element's text from 0 up to
// `data-count-up-target-value` over ~1.2s with requestAnimationFrame, then
// disconnects (animate once).
//
// Respects prefers-reduced-motion: when the user prefers reduced motion the
// final value is set immediately with no animation.
//
// Values:
//   target   (Number) — the number to count up to (data-count-up-target-value)
//   duration (Number) — animation length in ms (defaults to 1200)
export default class extends Controller {
  static values = { target: Number, duration: Number };

  connect() {
    this.endValue = this.targetValue || 0;
    this.duration = this.durationValue || 1200;

    // Reduced-motion users: show the final number immediately, no animation.
    if (this.prefersReducedMotion) {
      this.element.textContent = this.endValue.toString();
      return;
    }

    // Start at zero so the 0 → value count is visible once revealed.
    this.element.textContent = "0";

    this._observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          this.animate();
          this._observer.disconnect();
        });
      },
      { threshold: 0.1 }
    );
    this._observer.observe(this.element);
  }

  disconnect() {
    this._observer?.disconnect();
    if (this._raf) cancelAnimationFrame(this._raf);
  }

  animate() {
    const start = performance.now();
    const step = (now) => {
      const progress = Math.min((now - start) / this.duration, 1);
      this.element.textContent = Math.round(progress * this.endValue).toString();
      if (progress < 1) {
        this._raf = requestAnimationFrame(step);
      } else {
        this.element.textContent = this.endValue.toString();
      }
    };
    this._raf = requestAnimationFrame(step);
  }

  get prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }
}
