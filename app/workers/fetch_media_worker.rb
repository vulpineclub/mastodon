# frozen_string_literal: true

class FetchMediaWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 0

  def perform(media_attachment_id, remote_url = nil)
    object = MediaAttachment.find(media_attachment_id.to_i)
    return if object.blocked?
    if remote_url.nil?
      return if object.remote_url.nil?
    else
      object.remote_url = remote_url
    end
    object.file_remote_url = object.remote_url
    object.created_at      = Time.now.utc
    object.save!
  rescue ActiveRecord::RecordNotFound
    true
  end
end
