class Dev::NotificationsLabController < ApplicationController
  before_action :require_dev_env_or_admin!
  before_action :require_user!

  def show
    @types = Notifications::Registry.all
    @notifications = current_user.notifications.includes(:actor).order(created_at: :desc).limit(50).to_a
    Notification.preload_inbox_records!(@notifications)
  end

  def fire
    klass = Notifications::Registry.by_category(params[:category])
    return redirect_to(dev_notifications_lab_path, alert: "Unknown type") unless klass

    actor_id = params[:actor_id].presence || other_user_id_for_demo
    actor = User.find_by(id: actor_id)

    notification = klass.notify(
      recipient: current_user,
      actor: actor,
      record: nil,
      params: { lab: true }
    )

    if notification
      redirect_to dev_notifications_lab_path, notice: "Fired #{klass.name}"
    else
      redirect_to dev_notifications_lab_path, alert: "Skipped (self-notify guard or invalid input)"
    end
  end

  def wipe
    count = current_user.notifications.destroy_all.length
    redirect_to dev_notifications_lab_path, notice: "Wiped #{count} notifications"
  end

  private

  # Safety net: this is a dev tool meant to be deleted before prod. In case
  # it sneaks through, restrict to dev env OR admins so an arbitrary signed-in
  # user on prod can't wipe their own notifications via /dev/notifications_lab.
  def require_dev_env_or_admin!
    return if Rails.env.development?
    return if current_user&.admin?

    redirect_to root_path, alert: "Not available"
  end

  def require_user!
    return if current_user.present?

    redirect_to root_path, alert: "Sign in first"
  end

  def other_user_id_for_demo
    User.where.not(id: current_user.id).order(:id).limit(1).pluck(:id).first
  end
end
