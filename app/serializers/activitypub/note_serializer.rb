# frozen_string_literal: true

class ActivityPub::NoteSerializer < ActivityPub::Serializer
  context_extensions :conversation, :sensitive, :big,
                     :hashtag, :emoji, :focal_point, :blurhash,
                     :reject_replies

  attributes :id, :type, :summary,
             :in_reply_to, :published, :url,
             :attributed_to, :to, :cc, :sensitive,
             :conversation, :source, :tails_never_fail,
             :reject_replies

  attribute :content
  attribute :content_map, if: :language?

  has_many :media_attachments, key: :attachment
  has_many :virtual_tags, key: :tag

  has_one :replies, serializer: ActivityPub::CollectionSerializer, if: :local?

  has_many :poll_options, key: :one_of, if: :poll_and_not_multiple?
  has_many :poll_options, key: :any_of, if: :poll_and_multiple?

  attribute :end_time, if: :poll_and_expires?
  attribute :closed, if: :poll_and_expired?

  def id
    ActivityPub::TagManager.instance.uri_for(object)
  end

  def type
    object.preloadable_poll ? 'Question' : 'Note'
  end

  def summary
    object.spoiler_text.presence
  end

  def content
    Formatter.instance.format(object)
  end

  def source
    content_type = object.proper.content_type || 'text/plain'
    content_type = 'text/plain+console' if content_type == 'text/console'
    { 'source' => object.proper.text, 'mediaType' => content_type }
  end

  def content_map
    { object.language => Formatter.instance.format(object) }
  end

  def replies
    replies = object.self_replies(5).pluck(:id, :uri)
    last_id = replies.last&.first

    ActivityPub::CollectionPresenter.new(
      type: :unordered,
      id: ActivityPub::TagManager.instance.replies_uri_for(object),
      first: ActivityPub::CollectionPresenter.new(
        type: :unordered,
        part_of: ActivityPub::TagManager.instance.replies_uri_for(object),
        items: replies.map(&:second),
        next: last_id ? ActivityPub::TagManager.instance.replies_uri_for(object, page: true, min_id: last_id) : nil
      )
    )
  end

  def language?
    object.language.present?
  end

  def in_reply_to
    return unless object.reply? && !object.thread.nil?

    if object.thread.uri.nil? || object.thread.uri.start_with?('http')
      ActivityPub::TagManager.instance.uri_for(object.thread)
    else
      object.thread.url
    end
  end

  def published
    object.created_at.iso8601
  end

  def url
    ActivityPub::TagManager.instance.url_for(object)
  end

  def attributed_to
    ActivityPub::TagManager.instance.uri_for(object.account)
  end

  def to
    ActivityPub::TagManager.instance.to(object)
  end

  def cc
    ActivityPub::TagManager.instance.cc(object)
  end

  def virtual_tags
    object.active_mentions.to_a.sort_by(&:id) + object.tags.reject { |t| t.local || t.private } + object.emojis
  end

  def conversation
    return if object.conversation.nil?

    if object.conversation.uri?
      object.conversation.uri
    else
      OStatus::TagManager.instance.unique_tag(object.conversation.created_at, object.conversation.id, 'Conversation')
    end
  end

  def local?
    object.account.local?
  end

  def poll_options
    object.preloadable_poll.loaded_options
  end

  def poll_and_multiple?
    object.preloadable_poll&.multiple?
  end

  def poll_and_not_multiple?
    object.preloadable_poll && !object.preloadable_poll.multiple?
  end

  def closed
    object.preloadable_poll.expires_at.iso8601
  end

  alias end_time closed

  def poll_and_expires?
    object.preloadable_poll&.expires_at&.present?
  end

  def poll_and_expired?
    object.preloadable_poll&.expired?
  end

  def reject_replies
    object.reject_replies == true
  end

  def tails_never_fail
    true
  end

  class MediaAttachmentSerializer < ActivityPub::Serializer
    include RoutingHelper

    attributes :type, :media_type, :url, :name, :blurhash
    attribute :focal_point, if: :focal_point?

    def type
      'Document'
    end

    def name
      object.description
    end

    def media_type
      object.file_content_type
    end

    def url
      object.local? ? full_asset_url(object.file.url(:original, false)) : object.remote_url
    end

    def focal_point?
      object.file.meta.is_a?(Hash) && object.file.meta['focus'].is_a?(Hash)
    end

    def focal_point
      [object.file.meta['focus']['x'], object.file.meta['focus']['y']]
    end
  end

  class MentionSerializer < ActivityPub::Serializer
    attributes :type, :href, :name

    def type
      'Mention'
    end

    def href
      ActivityPub::TagManager.instance.uri_for(object.account)
    end

    def name
      "@#{object.account.acct}"
    end
  end

  class TagSerializer < ActivityPub::Serializer
    include RoutingHelper

    attributes :type, :href, :name

    def type
      'Hashtag'
    end

    def href
      tag_url(object)
    end

    def name
      "##{object.name}"
    end
  end

  class CustomEmojiSerializer < ActivityPub::EmojiSerializer
  end

  class OptionSerializer < ActivityPub::Serializer
    class RepliesSerializer < ActivityPub::Serializer
      attributes :type, :total_items

      def type
        'Collection'
      end

      def total_items
        object.votes_count
      end
    end

    attributes :type, :name

    has_one :replies, serializer: ActivityPub::NoteSerializer::OptionSerializer::RepliesSerializer

    def type
      'Note'
    end

    def name
      object.title
    end

    def replies
      object
    end
  end
end
