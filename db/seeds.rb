# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
loan_products = [
  {
    name: "Quick Cash Loan",
    description: "Fast approval for immediate cash needs. Perfect for emergencies and short-term financial requirements.",
    min_amount: 10_000,
    max_amount: 100_000,
    min_term_months: 3,
    max_term_months: 12,
    interest_rate_min: 18.0,
    interest_rate_max: 30.0,
    min_credit_score: 400,
    min_monthly_income: 30_000,
    requirements: [
      "Valid bank account connected for at least 3 months",
      "Minimum monthly income of ₦30,000",
      "Valid identification documents",
      "No active loan defaults"
    ],
    features: [
      "Quick approval within 24 hours",
      "No collateral required",
      "Flexible repayment terms",
      "Competitive interest rates"
    ]
  },
  {
    name: "Personal Loan",
    description: "Larger amounts for major purchases, debt consolidation, or significant life events.",
    min_amount: 50_000,
    max_amount: 1_000_000,
    min_term_months: 6,
    max_term_months: 36,
    interest_rate_min: 12.0,
    interest_rate_max: 25.0,
    min_credit_score: 550,
    min_monthly_income: 80_000,
    requirements: [
      "Good credit history for at least 6 months",
      "Minimum monthly income of ₦80,000",
      "Valid employment verification",
      "Bank account active for at least 6 months"
    ],
    features: [
      "Up to ₦1 million loan amount",
      "Extended repayment terms up to 3 years",
      "Lower interest rates for good credit",
      "No early repayment penalties"
    ]
  },
  {
    name: "Business Loan",
    description: "Capital for business growth, inventory, equipment, or working capital needs.",
    min_amount: 100_000,
    max_amount: 5_000_000,
    min_term_months: 12,
    max_term_months: 60,
    interest_rate_min: 15.0,
    interest_rate_max: 28.0,
    min_credit_score: 600,
    min_monthly_income: 150_000,
    requirements: [
      "Business registration documents",
      "Business bank account statements",
      "Minimum 1 year business operation",
      "Strong personal and business credit history"
    ],
    features: [
      "Up to ₦5 million for business needs",
      "Extended repayment terms up to 5 years",
      "Business-friendly interest rates",
      "Dedicated business support"
    ]
  },
  {
    name: "Premium Loan",
    description: "Exclusive offering for high-income earners with excellent credit. Best rates and terms available.",
    min_amount: 200_000,
    max_amount: 10_000_000,
    min_term_months: 12,
    max_term_months: 84,
    interest_rate_min: 8.0,
    interest_rate_max: 18.0,
    min_credit_score: 750,
    min_monthly_income: 500_000,
    requirements: [
      "Excellent credit score (750+)",
      "High monthly income (₦500,000+)",
      "Stable employment history",
      "Multiple bank accounts with good history"
    ],
    features: [
      "Premium interest rates from 8%",
      "Loan amounts up to ₦10 million",
      "Extended terms up to 7 years",
      "Dedicated relationship manager",
      "Priority processing and approval"
    ]
  }
]

puts "Creating loan products..."

loan_products.each do |product_data|
  product = LoanProduct.find_or_create_by(name: product_data[:name]) do |p|
    p.description = product_data[:description]
    p.min_amount = product_data[:min_amount]
    p.max_amount = product_data[:max_amount]
    p.min_term_months = product_data[:min_term_months]
    p.max_term_months = product_data[:max_term_months]
    p.interest_rate_min = product_data[:interest_rate_min]
    p.interest_rate_max = product_data[:interest_rate_max]
    p.min_credit_score = product_data[:min_credit_score]
    p.min_monthly_income = product_data[:min_monthly_income]
    p.requirements = product_data[:requirements]
    p.features = product_data[:features]
    p.active = true
  end
  
  puts "✓ Created loan product: #{product.name}"
end

puts "Loan products seeded successfully!"
