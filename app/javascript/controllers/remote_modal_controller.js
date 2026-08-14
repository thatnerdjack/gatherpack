import { Controller } from "@hotwired/stimulus"

// Drives a Bootstrap modal whose body is fetched into a turbo frame.
//
// Attach to the `.modal` element wrapping a `<turbo-frame>` (see
// shared/_remote_modal). The modal opens whenever the frame finishes loading
// content, closes when a form inside it submits successfully, and empties
// itself on close so reopening the same record always refetches.
export default class extends Controller {
  connect() {
    this.frame = this.element.querySelector("turbo-frame")
    if (!this.frame) return

    this.modal = bootstrap.Modal.getOrCreateInstance(this.element)

    this.onFrameLoad = this.onFrameLoad.bind(this)
    this.onSubmitEnd = this.onSubmitEnd.bind(this)
    this.onHidden = this.onHidden.bind(this)

    this.frame.addEventListener("turbo:frame-load", this.onFrameLoad)
    document.addEventListener("turbo:submit-end", this.onSubmitEnd)
    this.element.addEventListener("hidden.bs.modal", this.onHidden)
  }

  disconnect() {
    if (!this.frame) return

    this.frame.removeEventListener("turbo:frame-load", this.onFrameLoad)
    document.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    this.element.removeEventListener("hidden.bs.modal", this.onHidden)
    this.modal.dispose()
  }

  onFrameLoad() {
    // A frame emptied on close also fires this event; only open for content.
    if (this.frame.children.length > 0) this.modal.show()
  }

  onSubmitEnd(event) {
    if (event.detail.success && this.frame.contains(event.target)) this.modal.hide()
  }

  onHidden() {
    this.frame.innerHTML = ""
    this.frame.removeAttribute("src")
    this.frame.removeAttribute("complete")
  }
}
