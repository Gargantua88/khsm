FactoryBot.define do
  factory :question do
    answer1 { "#{rand(2000)}" }
    answer2 { "#{rand(2000)}" }
    answer3 { "#{rand(2000)}" }
    answer4 { "#{rand(2000)}" }

    sequence (:text) { |n| "Год рождения Алексея #{n}?" }

    sequence(:level) { |n| n % 15}
  end
end