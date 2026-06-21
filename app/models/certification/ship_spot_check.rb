# == Schema Information
#
# Table name: certification_ship_spot_checks
#
#  id            :bigint           not null, primary key
#  justification :text
#  rating        :integer          default("good"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  checker_id    :bigint           not null
#  ship_id       :bigint           not null
#
# Indexes
#
#  index_certification_ship_spot_checks_on_checker_id  (checker_id)
#  index_certification_ship_spot_checks_on_ship_id     (ship_id)
#  index_ship_spot_checks_unique_per_ship              (ship_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (checker_id => users.id)
#  fk_rails_...  (ship_id => certification_ship_reviews.id)
#
module Certification
  class ShipSpotCheck < ApplicationRecord
    self.table_name = "certification_ship_spot_checks"

    belongs_to :ship, class_name: "Certification::Ship", foreign_key: :ship_id
    belongs_to :checker, class_name: "User"

    has_paper_trail

    enum :rating, { good: 0, bad: 1 }, default: :good

    validates :rating, presence: true
    validates :justification, presence: true, if: :bad?
    validates :justification, length: { maximum: 5_000 }, allow_blank: true
    validates :ship_id, uniqueness: { message: "has already been spot-checked" }

    def self.leaderboard(period)
      scope = joins(:checker)
      scope = case period
              when :daily then scope.where("certification_ship_spot_checks.created_at >= ?", Time.current.beginning_of_day)
              when :weekly then scope.where("certification_ship_spot_checks.created_at >= ?", Time.current.beginning_of_week)
              else scope
              end

      scope
        .group("users.id", "users.display_name")
        .order(Arel.sql("count_all DESC"))
        .limit(10)
        .count
        .map { |(id, name), count| { id: id, name: name, count: count } }
    end
  end
end
