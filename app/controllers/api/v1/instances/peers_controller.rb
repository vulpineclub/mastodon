# frozen_string_literal: true

class Api::V1::Instances::PeersController < Api::BaseController
  before_action :require_enabled_api!

  skip_before_action :set_cache_headers
  skip_before_action :require_authenticated_user!, unless: :whitelist_mode?

  respond_to :json

  def index
    expires_in 1.day, public: true
    render_with_cache(expires_in: 1.day) { actively_federated_domains }
  end

  private

  def actively_federated_domains
    scope = if Settings.auto_reject_unknown
              Account.remote.where(suspended_at: nil, known: true)
            else
              Account.remote.where(suspended_at: nil)
            end

    scope.select(:domain).distinct(:domain).reorder(:domain).pluck(:domain)
  end

  def require_enabled_api!
    head 404 unless Setting.peers_api_enabled && !whitelist_mode?
  end
end
