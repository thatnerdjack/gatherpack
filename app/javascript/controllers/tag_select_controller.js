import { Controller } from "@hotwired/stimulus"

// Single-choice tag picker backed by two hidden fields: one holding the id of
// an existing record, the other the name of one the user typed that doesn't
// exist yet. Exactly one of them is ever populated, so the server either links
// to the chosen record or creates it alongside the parent.
//
// Markup lives in teams/_team_type_field; the "new tag" input is only rendered
// when the user is allowed to create the underlying record.
export default class extends Controller {
  static targets = ["idField", "nameField", "list", "option", "input"]

  connect() {
    this.highlight()
  }

  select(event) {
    this.idFieldTarget.value = event.params.id || ""
    this.nameFieldTarget.value = event.params.name || ""
    this.highlight()
  }

  add(event) {
    event.preventDefault()

    const name = this.inputTarget.value.trim()
    if (name === "") return

    const existing = this.optionTargets.find(
      (option) => option.textContent.trim().toLowerCase() === name.toLowerCase()
    )

    if (existing) {
      existing.click()
    } else {
      this.listTarget.appendChild(this.buildOption(name))
      this.idFieldTarget.value = ""
      this.nameFieldTarget.value = name
      this.highlight()
    }

    this.inputTarget.value = ""
  }

  buildOption(name) {
    const option = document.createElement("button")
    option.type = "button"
    option.className = "btn btn-sm tag-select-option"
    option.textContent = name
    option.dataset.tagSelectTarget = "option"
    option.dataset.action = "tag-select#select"
    option.dataset.tagSelectNameParam = name
    return option
  }

  // A tag is selected when its id matches the id field, or — for a tag added in
  // this session — when its name matches the pending name field.
  highlight() {
    const id = this.idFieldTarget.value
    const name = this.nameFieldTarget.value

    this.optionTargets.forEach((option) => {
      const selected = option.dataset.tagSelectIdParam
        ? option.dataset.tagSelectIdParam === id && id !== ""
        : option.dataset.tagSelectNameParam === name && name !== ""

      option.classList.toggle("active", selected)
      option.setAttribute("aria-pressed", selected)
    })
  }
}
