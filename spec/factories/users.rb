FactoryBot.define do
  factory :user do
    name { "Бот№#{rand(999)}" }

    sequence(:email) { |n| "johndoe_#{n}@example.com" }

    is_admin { false }

    balance { 0 }

    after(:build) { |u| u.password_confirmation = u.password = "123456"}
  end
end