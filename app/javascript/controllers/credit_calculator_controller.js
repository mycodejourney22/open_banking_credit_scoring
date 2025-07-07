// app/javascript/controllers/credit_calculator_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "term", "rate", "monthly", "total"]
  static values = { maxAmount: Number }

  connect() {
    this.calculate()
  }

  calculate() {
    const amount = parseFloat(this.amountTarget.value) || 0
    const termMonths = parseInt(this.termTarget.value) || 12
    const annualRate = parseFloat(this.rateTarget.dataset.rate) || 0.15
    
    if (amount > this.maxAmountValue) {
      this.amountTarget.value = this.maxAmountValue
      return
    }
    
    const monthlyRate = annualRate / 12
    const monthlyPayment = amount * (monthlyRate * Math.pow(1 + monthlyRate, termMonths)) / 
                          (Math.pow(1 + monthlyRate, termMonths) - 1)
    
    const totalPayment = monthlyPayment * termMonths
    
    this.monthlyTarget.textContent = `₦${monthlyPayment.toLocaleString('en-NG', {maximumFractionDigits: 0})}`
    this.totalTarget.textContent = `₦${totalPayment.toLocaleString('en-NG', {maximumFractionDigits: 0})}`
  }
}