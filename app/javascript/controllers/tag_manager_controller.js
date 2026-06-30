import { Controller } from "@hotwired/stimulus"

// Handles inline tag creation and deletion inside the blog post new/edit forms.
// Creates tags via POST /tags (JSON), deletes via DELETE /tags/:id (JSON).
// Dynamically adds/removes checkboxes without a page reload.
export default class extends Controller {
  static targets = ["nameInput", "tagList", "addButton", "hint"]

  async addTag(event) {
    event.preventDefault()
    const name = this.nameInputTarget.value.trim()
    if (!name) return

    this.addButtonTarget.disabled = true
    this.clearHint()

    try {
      const response = await fetch("/tags", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ tag: { name } })
      })

      const data = await response.json()

      if (!response.ok) {
        this.showHint(data.error || "Could not create tag.", "error")
        return
      }

      this.appendTag(data)
      this.nameInputTarget.value = ""

      // Remove "no tags yet" empty notice if present
      const empty = this.tagListTarget.querySelector(".tag-manager-empty")
      if (empty) empty.remove()
    } catch (_e) {
      this.showHint("Network error — please try again.", "error")
    } finally {
      this.addButtonTarget.disabled = false
    }
  }

  appendTag({ id, name }) {
    // If tag already exists in list, just check it
    const existing = this.tagListTarget.querySelector(`[data-tag-id="${id}"]`)
    if (existing) {
      const checkbox = existing.querySelector("input[type=checkbox]")
      if (checkbox) checkbox.checked = true
      this.showHint(`"${name}" is already in the list — checked it for you.`, "info")
      return
    }

    const item = document.createElement("div")
    item.className = "tag-checkbox-item"
    item.dataset.tagId = id
    item.innerHTML = `
      <label class="tag-checkbox-label">
        <input type="checkbox" name="blog_post[tag_ids][]" value="${id}" id="tag_${id}" class="tag-checkbox-input" checked>
        <span class="tag-checkbox-name">${this.escapeHtml(name)}</span>
      </label>
      <button type="button"
              class="tag-delete-btn"
              title="Delete tag globally"
              data-action="click->tag-manager#deleteTag"
              data-tag-id="${id}">
        <i class="fa-solid fa-xmark"></i>
      </button>
    `
    this.tagListTarget.appendChild(item)
    this.showHint(`"${name}" added and checked.`, "success")
  }

  async deleteTag(event) {
    event.preventDefault()
    const tagId = event.currentTarget.dataset.tagId
    const item = this.tagListTarget.querySelector(`[data-tag-id="${tagId}"]`)
    const tagName = item?.querySelector(".tag-checkbox-name")?.textContent || "this tag"

    if (!confirm(`Delete "${tagName}"? It will be removed from all blog posts.`)) return

    try {
      const response = await fetch(`/tags/${tagId}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        }
      })

      if (!response.ok) {
        this.showHint("Could not delete tag.", "error")
        return
      }

      if (item) item.remove()

      // Show empty notice if no tags remain
      if (this.tagListTarget.querySelectorAll(".tag-checkbox-item").length === 0) {
        const notice = document.createElement("p")
        notice.className = "text-muted small tag-manager-empty"
        notice.textContent = "No tags yet. Add one below."
        this.tagListTarget.appendChild(notice)
      }
    } catch (_e) {
      this.showHint("Network error — please try again.", "error")
    }
  }

  // ---- helpers ----

  get csrfToken() {
    return document.querySelector("meta[name=csrf-token]")?.content || ""
  }

  showHint(message, type = "info") {
    const colors = { success: "#89D6CC", error: "#f87171", info: "#9CA3AF" }
    this.hintTarget.textContent = message
    this.hintTarget.style.color = colors[type] || colors.info
  }

  clearHint() {
    this.hintTarget.textContent = ""
  }

  escapeHtml(str) {
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
