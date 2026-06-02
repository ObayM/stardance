# frozen_string_literal: true

Achievement = Data.define(:slug, :name, :description, :icon, :earned_check, :progress, :visibility, :secret_hint, :excluded_from_count, :stardust_reward) do
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  self::VISIBILITIES = %i[visible secret hidden].freeze

  def initialize(slug:, name:, description:, icon:, earned_check:, progress: nil, visibility: :visible, secret_hint: nil, excluded_from_count: false, stardust_reward: 0)
    super(slug:, name:, description:, icon:, earned_check:, progress:, visibility:, secret_hint:, excluded_from_count:, stardust_reward:)
  end

  self::ALL = [
    new(
      slug: :super_star,
      name: "Super Star",
      description: "Cooked so hard you ended up making a fire project that made our staff very happy!",
      icon: "fire",
      earned_check: ->(user) { user.projects.fire.exists? },
      visibility: :secret
    )
  ].freeze

  self::SECRET = (Secrets.available? ? Secrets::SecretAchievements::DEFINITIONS.map { |d| new(**d) } : []).freeze

  self::ALL_WITH_SECRETS = (self::ALL + self::SECRET).freeze
  self::SLUGGED = self::ALL_WITH_SECRETS.index_by(&:slug).freeze
  self::ALL_SLUGS = self::SLUGGED.keys.freeze

  class << self
    def all = self::ALL_WITH_SECRETS

    def slugged = self::SLUGGED

    def all_slugs = self::ALL_SLUGS

    def find(slug) = self::SLUGGED.fetch(slug.to_sym)

    alias_method :[], :find

    def countable
      self::ALL_WITH_SECRETS.reject(&:excluded_from_count)
    end

    def countable_for_user(user)
      countable.select { |a| a.shown_to?(user, earned: a.earned_by?(user)) }
    end
  end

  def to_param = slug

  def persisted? = true

  def visible? = visibility == :visible
  def secret? = visibility == :secret
  def hidden? = visibility == :hidden

  def shown_to?(user, earned:)
    return true if earned
    return true if visible?
    return true if secret?

    false
  end

  def earned_by?(user) = earned_check.call(user)

  def progress_for(user)
    return nil unless progress

    progress.call(user)
  end

  def has_progress? = progress.present?

  def has_stardust_reward? = stardust_reward.positive?

  self::SECRET_DESCRIPTIONS = [
    "the secret to this one is... secret",
    "something's brewing... 👀",
    "this one's under wraps",
    "only the team knows this one",
    "a mystery awaits...",
    "keep building to find out!",
    "classified intel 🤫",
    "shhh... it's in the works"
  ].freeze

  def display_name(earned:)
    return name if earned || visible?

    secret? ? "???" : name
  end

  def display_description(earned:)
    return description if earned || visible?

    secret_hint || self.class::SECRET_DESCRIPTIONS.sample
  end

  def show_progress?(earned:)
    return false if earned
    return false unless has_progress?
    return false if hidden?

    true
  end
end
