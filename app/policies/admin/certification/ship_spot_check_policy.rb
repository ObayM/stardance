# frozen_string_literal: true

class Admin::Certification::ShipSpotCheckPolicy < ApplicationPolicy
  def index?   = user&.admin?
  def create?  = user&.admin?
end
