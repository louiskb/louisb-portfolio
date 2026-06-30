// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "@popperjs/core"
import "bootstrap"

import "trix"
import "@rails/actiontext"

// ===== TRIX HEADING EXTENSION =====
// Registers h2/h3 block attributes before any editor initialises,
// then injects H2 and H3 buttons into every Trix toolbar.
addEventListener("trix-before-initialize", () => {
  Trix.config.blockAttributes.heading2 = {
    tagName: "h2",
    terminal: true,
    breakOnReturn: true,
    group: false
  }
  Trix.config.blockAttributes.heading3 = {
    tagName: "h3",
    terminal: true,
    breakOnReturn: true,
    group: false
  }
})

addEventListener("trix-initialize", ({ target: editor }) => {
  const blockTools = editor.toolbarElement.querySelector(".trix-button-group--block-tools")
  if (!blockTools) return

  const makeBtn = (label, attribute) => {
    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = "trix-button trix-button--heading"
    btn.title = `Heading ${label}`
    btn.textContent = `H${label}`
    btn.dataset.trixAttribute = attribute
    return btn
  }

  blockTools.prepend(makeBtn(3, "heading3"))
  blockTools.prepend(makeBtn(2, "heading2"))
})
