// app/javascript/controllers/auto_sync_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { interval: Number, url: String }

  connect() {
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.timer = setInterval(() => {
      this.sync()
    }, this.intervalValue || 30000) // Default 30 seconds
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  async sync() {
    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Content-Type': 'application/json'
        }
      })
      
      if (response.ok) {
        // Reload the page or specific sections
        window.location.reload()
      }
    } catch (error) {
      console.error('Sync failed:', error)
    }
  }
}