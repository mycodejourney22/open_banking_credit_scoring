FactoryBot.define do
  factory :bank_connection do
    bank_code { "MyString" }
    bank_name { "MyString" }
    account_number { "MyString" }
    account_name { "MyString" }
    account_type { "MyString" }
    encrypted_access_token { "MyText" }
    encrypted_refresh_token { "MyText" }
    token_expires_at { "2025-07-07 20:21:17" }
    consent_id { "MyString" }
    status { "MyString" }
    last_synced_at { "2025-07-07 20:21:17" }
    user { nil }
  end
end
