require 'game_help_generator'

class Game < ActiveRecord::Base
  # Константы, задающие механику игры: призы за каждый
  # вопрос, номера несгораемых уровней и лимит времени на игру
  PRIZES = [100, 200, 300, 500, 1_000, 2_000, 4_000, 8_000, 16_000,
            32_000, 64_000, 125_000, 250_000, 500_000, 1_000_000].freeze
  FIREPROOF_LEVELS = [4, 9, 14].freeze
  TIME_LIMIT = 35.minutes

  belongs_to :user
  has_many :game_questions, dependent: :destroy

  validates :user, presence: true

  # Текущий уровень сложности вопроса: число от 0 до 14
  validates :current_level, numericality: {only_integer: true}, allow_nil: false
  validates :prize, presence: true, numericality: {
    greater_than_or_equal_to: 0, less_than_or_equal_to: PRIZES.last
  }

  scope :in_progress, -> { where(finished_at: nil) }

  def self.create_game_for_user!(user)
    # Все действия делаем транзакцией, если где-то словим исключение - откатятся все изменения в базе.
    transaction do
      # Создаем игру для данного игрока
      game = create!(user: user)

      # Созданной игре добавляем ровно 15 новых игровых вопросов разного уровня
      Question::QUESTION_LEVELS.each do |level|
        question = Question.where(level: level).order('RANDOM()').first

        # Перемешиваем ответы
        answers = [1, 2, 3, 4].shuffle

        # Создаем объект GameQuestion и цепляем его к игре
        game.game_questions.create!(
          question: question,
          a: answers.pop, b: answers.pop, c: answers.pop, d: answers.pop
        )
      end
      game
    end
  end

  def current_game_question
    game_questions.detect { |q| q.question.level == current_level }
  end

  def previous_level
    current_level - 1
  end

  def finished?
    finished_at.present?
  end

  def time_out!
    if (Time.now - created_at) > TIME_LIMIT
      finish_game!(fire_proof_prize(previous_level), true)
      true
    end
  end

  def answer_current_question!(letter)
    return false if time_out! || finished?

    if current_game_question.answer_correct?(letter)
      self.current_level += 1

      if current_level == Question::QUESTION_LEVELS.max + 1
        finish_game!(PRIZES[Question::QUESTION_LEVELS.max], false)
      else
        save!
      end

      true
    else
      finish_game!(fire_proof_prize(previous_level), true)
      false
    end
  end

  def take_money!
    return if time_out! || finished?

    finish_game!(previous_level > -1 ? PRIZES[previous_level] : 0, false)
  end

  def use_help(help_type)
    help_types = %i(fifty_fifty audience_help friend_call)
    help_type = help_type.to_sym
    raise ArgumentError.new('wrong help_type') unless help_types.include?(help_type)

    unless self["#{help_type}_used"]
      self["#{help_type}_used"] = true
      current_game_question.apply_help!(help_type)
      save
    end
  end

  # :fail — игра проиграна из-за неверного вопроса
  # :timeout — игра проиграна из-за таймаута
  # :won — игра выиграна (все 15 вопросов отвечены)
  # :money — игра завершена, игрок забрал деньги
  # :in_progress — игра еще идет
  def status
    return :in_progress unless finished?

    if is_failed
      (finished_at - created_at) > TIME_LIMIT ? :timeout : :fail
    elsif current_level > Question::QUESTION_LEVELS.max
      :won
    else
      :money
    end
  end

  private

  def finish_game!(amount = 0, failed = true)
    # Оборачиваем в транзакцию — игра заканчивается и баланс юзера пополняется
    # только вместе.
    transaction do
      self.prize = amount
      self.finished_at = Time.now
      self.is_failed = failed
      user.balance += amount
      save!
      user.save!
    end
  end

  def fire_proof_prize(answered_level)
    level = FIREPROOF_LEVELS.select { |x| x <= answered_level }.last
    level.present? ? PRIZES[level] : 0
  end
end
