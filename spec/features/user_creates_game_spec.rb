require 'rails_helper'

RSpec.feature 'user creates game', type: :feature do
  let(:user) { FactoryBot.create :user }

  let!(:questions) do
    (0..14).to_a.map do |i|
      FactoryBot.create(
                    :question, level: i,
                    text: "Когда родился Алексей #{i}?",
                    answer1: "1200", answer2: "1201", answer3: "1202", answer4: "1203"
      )
    end
  end

  before(:each) do
    login_as user
  end

  scenario 'success' do
    visit '/'

    click_link 'Новая игра'

    expect(page).to have_content('Когда родился Алексей 0?')
    expect(page).to have_content('1200')
    expect(page).to have_content('1201')
    expect(page).to have_content('1202')
    expect(page).to have_content('1203')
  end
end