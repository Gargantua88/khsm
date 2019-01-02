require 'rails_helper'

require 'support/my_spec_helper'

RSpec.describe Game, type: :model do
  let(:user) { FactoryBot.create(:user) }

  let(:game_w_questions) do
    FactoryBot.create(:game_with_questions, user: user)
  end

  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      generate_questions(60)

      game = nil

      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(
          change(GameQuestion, :count).by(15).and(
              change(Question, :count).by(0)
          )
      )

      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)

      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  context 'game mechanics' do
    it 'correct .current_game_question' do
      game_w_questions.current_level = 7
      expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions[7])
    end

    context '.previous_level' do
      it 'correct .previous_level on start game' do
        expect(game_w_questions.previous_level).to eq(-1)
      end

      it 'correct .previous_level on level 7' do
        game_w_questions.current_level = 7
        expect(game_w_questions.previous_level).to eq(6)
      end
    end

    it 'answer correct continues game' do
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      expect(game_w_questions.current_level).to eq(level + 1)

      expect(game_w_questions.current_game_question).not_to eq(q)

      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it 'player take money' do
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      game_w_questions.take_money!

      expect(game_w_questions.status).to eq(:money)
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq(game_w_questions.prize)
    end
  end

  context '.status' do
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it 'return won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq(:won)
    end

    it ':fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:fail)
    end

    it ':timeout' do
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:timeout)
    end

    it ':money' do
      expect(game_w_questions.status).to eq(:money)
    end
  end

  context '.answer_current_question!' do
    it 'answer is correct' do
      level = game_w_questions.current_level
      expect(game_w_questions.answer_current_question!('d')).to be_truthy
      expect(game_w_questions.current_level).to eq(level + 1)
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it 'answer is correct and last' do
      game_w_questions.current_level = 14
      expect(game_w_questions.answer_current_question!('d')).to be_truthy
      expect(game_w_questions.status).to eq(:won)
      expect(game_w_questions.finished?).to be_truthy
    end

    it 'answer is incorrect' do
      expect(game_w_questions.answer_current_question!('a')).to be_falsey
      expect(game_w_questions.status).to eq(:fail)
      expect(game_w_questions.finished?).to be_truthy
    end

    it 'time is up' do
      game_w_questions.created_at = 1.hour.ago
      expect(game_w_questions.answer_current_question!('d')).to be_falsey
      expect(game_w_questions.status).to eq(:timeout)
      expect(game_w_questions.finished?).to be_truthy
    end
  end
end
