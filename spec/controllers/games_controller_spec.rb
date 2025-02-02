require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController, type: :controller do

  let(:user) { FactoryBot.create(:user) }

  let(:admin) { FactoryBot.create(:user, is_admin: true) }

  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  context 'anonymous user' do
    it 'kick from #show' do
      get :show, id: game_w_questions.id
      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #create' do
      generate_questions(60)

      post :create
      game = assigns(:game)

      expect(game).to be_nil
      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #take_money' do
      put :take_money, id: game_w_questions.id
      game = assigns(:game)

      expect(game).to be_nil
      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #answer' do
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)

      expect(game).to be_nil
      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end
  end

  context 'logged user' do

    before(:each) do
      sign_in user
    end

    it 'creates game' do
      generate_questions(60)

      post :create
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      expect(response).to redirect_to game_path(game)
      expect(flash[:notice]).to be
    end

    it 'show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      expect(response.status).to eq 200
      expect(response).to render_template('show')
    end

    it 'answer correct' do
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.current_level).to be > 0
      expect(response).to redirect_to game_path(game)
      expect(flash.empty?).to be_truthy
    end

    it 'answer incorrect' do
      game_w_questions.update_attribute(:current_level, 12)
      put :answer, id: game_w_questions.id, letter: 'e'
      game = assigns(:game)

      expect(game.finished?).to be_truthy
      expect(game.status).to eq(:fail)
      expect(response).to redirect_to(user_path(user))
      expect(flash[:alert]).to be
      expect(game.prize).to eq(32000)

      user.reload
      expect(user.balance).to eq(32000)
    end

    it 'kick another user from #show' do
      another_game = FactoryBot.create(:game_with_questions)
      get :show, id: another_game.id

      expect(response.status).not_to eq 200
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be
    end

    it 'user take money' do
      game_w_questions.update_attribute(:current_level, 14)
      put :take_money, id: game_w_questions.id
      game = assigns(:game)

      expect(game.finished?).to be_truthy
      expect(game.status).to eq(:money)
      expect(game.prize).to eq(500000)

      user.reload
      expect(user.balance).to eq(500000)

      expect(response).to redirect_to(user_path(user))
      expect(flash[:warning]).to be
    end

    it 'kick user from new game' do
      expect(game_w_questions.finished?).to be_falsey
      expect { post :create }.to change(Game, :count).by(0)
      game = assigns(:game)
      expect(game).to be_nil
      expect(response).to redirect_to(game_path(game_w_questions))
      expect(flash[:alert]).to be
    end

    it 'uses audience help' do
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be_falsey

      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.audience_help_used).to be_truthy
      expect(game.current_game_question.help_hash[:audience_help]).to be
      expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      expect(response).to redirect_to(game_path(game))
    end

    it 'uses fifty_fifty' do
      expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
      expect(game_w_questions.fifty_fifty_used).to be_falsey

      put :help, id: game_w_questions.id, help_type: :fifty_fifty
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.fifty_fifty_used).to be_truthy

      test_hash = game.current_game_question.help_hash[:fifty_fifty]

      expect(test_hash).to be
      expect(test_hash).to include('d')
      expect(test_hash.size).to eq(2)
      expect(response).to redirect_to(game_path(game))
    end

    it 'uses friend_call' do
      expect(game_w_questions.current_game_question.help_hash[:friend_call]).not_to be
      expect(game_w_questions.friend_call_used).to be_falsey

      put :help, id: game_w_questions.id, help_type: :friend_call
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.friend_call_used).to be_truthy
      expect(game.current_game_question.help_hash[:friend_call]).to be

      test_hash = game.current_game_question.help_hash[:friend_call]

      expect(test_hash).to include('считает, что это вариант')
      expect(test_hash.last.downcase).to be_in(%w(a b c d))
    end
  end
end
