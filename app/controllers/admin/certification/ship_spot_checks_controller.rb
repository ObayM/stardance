class Admin::Certification::ShipSpotChecksController < Admin::Certification::ApplicationController
  before_action :set_body_class

  def index
    authorize ::Certification::ShipSpotCheck, policy_class: Admin::Certification::ShipSpotCheckPolicy

    @reviewer_id = params[:reviewer_id].presence
    @status      = params[:status].presence_in(%w[approved returned all]) || "all"
    @sort        = params[:sort] == "oldest" ? "oldest" : "newest"
    @rating      = params[:rating].presence_in(%w[good bad unchecked]) || "unchecked"

    @reviewers = User.joins(
      "INNER JOIN certification_ship_reviews ON certification_ship_reviews.reviewer_id = users.id"
    ).where.not("certification_ship_reviews.status" => 0)
      .distinct
      .order(:display_name)

    scope = ::Certification::Ship
      .joins(:project, :reviewer)
      .where.not(status: :pending)
      .where(projects: { deleted_at: nil })
      .includes(:reviewer, :spot_check, project: { memberships: :user })

    scope = scope.where(reviewer_id: @reviewer_id) if @reviewer_id.present?
    scope = scope.where(status: @status) unless @status == "all"

    scope = case @rating
            when "unchecked"
              scope.where.missing(:spot_check)
            when "good"
              scope.joins(:spot_check).where(certification_ship_spot_checks: { rating: :good })
            when "bad"
              scope.joins(:spot_check).where(certification_ship_spot_checks: { rating: :bad })
            else
              scope
            end

    scope = scope.order(decided_at: @sort == "oldest" ? :asc : :desc)

    @pagy, @ships = pagy(:offset, scope, limit: 25)

    @spot_checks_by_ship = ::Certification::ShipSpotCheck
      .where(ship_id: @ships.map(&:id))
      .index_by(&:ship_id)

    @stats = spot_check_stats

    @lb_period = params[:lb].presence_in(%w[daily weekly alltime]) || "daily"
    @leaderboards = {
      "daily" => ::Certification::ShipSpotCheck.leaderboard(:daily),
      "weekly" => ::Certification::ShipSpotCheck.leaderboard(:weekly),
      "alltime" => ::Certification::ShipSpotCheck.leaderboard(:alltime)
    }
  end

  def create
    authorize ::Certification::ShipSpotCheck, policy_class: Admin::Certification::ShipSpotCheckPolicy

    @ship = ::Certification::Ship.find(params[:ship_id])
    @spot_check = ::Certification::ShipSpotCheck.find_or_initialize_by(ship_id: @ship.id)
    @spot_check.assign_attributes(spot_check_params.merge(checker: current_user))

    if @spot_check.save
      redirect_back_or_to spot_checks_admin_certification_ships_path(return_params),
                          notice: "Spot check recorded for \"#{@ship.project.title}\"."
    else
      redirect_back_or_to spot_checks_admin_certification_ships_path(return_params),
                          alert: "Couldn't save spot check: #{@spot_check.errors.full_messages.to_sentence}"
    end
  end

  private

  def set_body_class
    @body_class = "app-layout-page"
  end

  def spot_check_params
    params.require(:certification_ship_spot_check).permit(:rating, :justification)
  end

  def return_params
    params.permit(:reviewer_id, :status, :sort, :rating, :page)
  end

  def spot_check_stats
    all_decided = ::Certification::Ship.where.not(status: :pending).count
    checked     = ::Certification::ShipSpotCheck.count
    good_count  = ::Certification::ShipSpotCheck.good.count
    bad_count   = ::Certification::ShipSpotCheck.bad.count

    {
      total_decided: all_decided,
      checked: checked,
      unchecked: all_decided - checked,
      good: good_count,
      bad: bad_count,
      coverage_pct: all_decided.zero? ? nil : (checked * 100.0 / all_decided).round(1)
    }
  end
end
