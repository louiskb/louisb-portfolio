import { Controller } from "@hotwired/stimulus"

// Manages the split publish button on blog post / project forms.
// Controls hidden status + scheduled_at fields so the UI can drive the
// publishing workflow (draft / publish now / schedule) without exposing raw
// select inputs to the owner.
export default class extends Controller {
  static targets = ["statusInput", "scheduledAtInput", "scheduleInput"]
  static values = { currentStatus: String }

  // Default action — save the post as a draft.
  // Asks for confirmation if the post is currently published (would unpublish it).
  saveDraft(event) {
    event.preventDefault()
    if (this.currentStatusValue === "published") {
      if (!confirm("This will unpublish the post and move it back to draft. Continue?")) {
        // showSpinner already hid the buttons — restore them so the user isn't frozen.
        this._restoreLoadButtonState()
        return
      }
    }
    this.statusInputTarget.value = "draft"
    this.scheduledAtInputTarget.value = ""
    this.element.requestSubmit()
  }

  // Save without touching the status field (used on the edit form
  // when the owner just wants to update content without changing state).
  saveChanges(event) {
    event.preventDefault()
    this.element.requestSubmit()
  }

  // Publish immediately.
  publishNow(event) {
    event.preventDefault()
    this.statusInputTarget.value = "published"
    this.scheduledAtInputTarget.value = ""
    this.element.requestSubmit()
  }

  // Called by the "Schedule post" button inside the schedule modal.
  // Validates the datetime, sets the hidden fields, closes the modal,
  // then submits the form.
  //
  // Safe to use alongside load-button#showSpinner (which fires first in
  // action order). If validation fails, _restoreLoadButtonState() undoes
  // the spinner so the user isn't left with a frozen UI.
  confirmSchedule(event) {
    event.preventDefault()
    const val = this.scheduleInputTarget.value

    if (!val) {
      // showSpinner may have already hidden the buttons — restore them
      // so the user can still interact with the form.
      this._restoreLoadButtonState()
      this.scheduleInputTarget.reportValidity()
      return
    }

    this.statusInputTarget.value = "scheduled"
    this.scheduledAtInputTarget.value = val

    const modalEl = this.element.querySelector("#schedulePostModal")
    if (modalEl) {
      // Bootstrap ships as a UMD bundle via importmap, so the Modal class lives
      // on window.bootstrap — never `import { Modal } from "bootstrap"`.
      const Modal = window.bootstrap?.Modal
      // getInstance returns the existing shown instance.
      // If it's somehow null (edge case), fall back to submitting immediately
      // rather than creating a never-shown Modal whose hide() is a no-op.
      const bsModal = Modal?.getInstance(modalEl)
      if (bsModal) {
        modalEl.addEventListener("hidden.bs.modal", () => {
          this.element.requestSubmit()
        }, { once: true })
        bsModal.hide()
      } else {
        this.element.requestSubmit()
      }
    } else {
      this.element.requestSubmit()
    }
  }

  // Undoes the spinner that load-button#showSpinner inserted before this
  // controller had a chance to validate. Called on early-exit paths only.
  _restoreLoadButtonState() {
    const buttonsEl = this.element.querySelector("[data-load-button-target='buttons']")
    if (!buttonsEl) return
    buttonsEl.classList.remove("d-none")
    const spinner = buttonsEl.nextElementSibling
    if (spinner?.querySelector?.(".fa-hourglass")) spinner.remove()
  }
}
