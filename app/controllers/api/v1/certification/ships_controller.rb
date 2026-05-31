class Api::V1::Certification::ShipsController < Api::V1::Certification::BaseController
  # GET /api/v1/certification/ships
  #
  # Returns ship certifications within a specific time frame!
  #
  # Query params:
  #   hours (integer, default 24)
  #   since (ISO 8601 datetime)
  #   until (ISO 8601 datetime)
  #   status (pending|approved|returned|all, default all)
  def index
    window_start, window_end = parse_time_window
    status_filter = params[:status].presence_in(%w[pending approved returned]) || "all"

    scope = ::Certification::Ship.includes(:reviewer, project: { memberships: :user })
    scope = scope.where(created_at: window_start..window_end) if window_start

    scope = scope.where(status: status_filter) unless status_filter == "all"

    render json: {
      window: window_start ? { from: window_start.iso8601, to: window_end.iso8601 } : nil,
      status_filter: status_filter,
      count: scope.size,
      ships: scope.order(created_at: :desc).map { |ship| serialize_ship(ship) }
    }
  end

  private

  def parse_time_window
    now = Time.current

    # No time params at all then return nil so caller skips the filter :)
    return [ nil, nil ] if params[:hours].blank? && params[:since].blank? && params[:until].blank?

    window_end = parse_time_param(params[:until]) || now

    window_start = if params[:since].present?
      parse_time_param(params[:since]) || (now - 24.hours)
    else
      hours = params[:hours].to_i
      hours = 24 if hours <= 0
      window_end - hours.hours
    end

    [ window_start, window_end ]
  end

  def parse_time_param(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def serialize_ship(ship)
    project = ship.project
    owner_membership = project.memberships.find { |m| m.role == "owner" }
    owner = owner_membership&.user
    reviewer = ship.reviewer

    {
      id: ship.id,
      status: ship.status,
      created_at: ship.created_at.iso8601,
      updated_at: ship.updated_at.iso8601,
      decided_at: ship.decided_at&.iso8601,
      claimed_at: ship.claimed_at&.iso8601,
      feedback: ship.feedback,
      project: {
        id: project.id,
        title: project.title,
        ship_status: project.ship_status,
        demo_url: project.demo_url,
        repo_url: project.repo_url,
        description: project.description,
        duration_seconds: project.duration_seconds,
        shipped_at: project.shipped_at&.iso8601
      },
      owner: owner ? {
        id: owner.id,
        display_name: owner.display_name,
        slack_id: owner.slack_id
      } : nil,
      reviewer: reviewer ? {
        id: reviewer.id,
        display_name: reviewer.display_name,
        slack_id: reviewer.slack_id
      } : nil
    }
  end
end
