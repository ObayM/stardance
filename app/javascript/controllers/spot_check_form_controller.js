import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["justification"]

  toggleJustification(event) {
    const isBad = event.target.value === "bad"
    this.justificationTargets.forEach(el => {
      el.style.display = isBad ? "" : "none"
    })
  }
}
