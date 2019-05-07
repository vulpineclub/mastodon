# frozen_string_literal: true

class RejectFollowService < BaseService
  def call(source_account, target_account)
    follow_request = FollowRequest.find_by!(account: source_account, target_account: target_account)
    follow_request.reject!
    create_notification(follow_request) unless source_account.local?
    follow_request
  end

  private

  def create_notification(follow_request)
    ActivityPub::DeliveryWorker.perform_async(build_json(follow_request), follow_request.target_account_id, follow_request.account.inbox_url)
  end

  def build_json(follow_request)
    ActiveModelSerializers::SerializableResource.new(
      follow_request,
      serializer: ActivityPub::RejectFollowSerializer,
      adapter: ActivityPub::Adapter
    ).to_json
  end
end
