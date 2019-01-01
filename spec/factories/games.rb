FactoryBot.define do
  factory :game do
    association :user

    finished_at { nil }
    current_level { 0 }
    is_failed { false }
    prize { 0 }

    factory :game_with_questions do

      after(:build) do |game|
        15.times do |level|
          question = create(:question, level: level)
          create(:game_question, game: game, question: question)
        end
      end
    end
  end
end