# frozen_string_literal: true

class Api::V1::Timelines::TagController < Api::BaseController
  before_action :load_tag
  after_action :insert_pagination_headers, unless: -> { @statuses.empty? }

  respond_to :json

  def show
    @statuses = load_statuses
    render json: @statuses, each_serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id)
  end

  private

  def load_tag
    @tag = Tag.find_normalized(params[:id])
  end

  def load_statuses
    cached_tagged_statuses
  end

  def cached_tagged_statuses
    cache_collection tagged_statuses, Status
  end

  def tagged_statuses
    if @tag.nil?
      []
    elsif @tag.name.in?(['self.bookmarks', '.self.bookmarks'])
      bookmarks = Status.reorder(nil).joins(:bookmarks).merge(bookmark_results)
      preload_media(bookmarks)
      bookmarks
    else
      tag_timeline = tag_timeline_statuses
      preload_media(tag_timeline.paginate_by_id(
        DEFAULT_STATUSES_LIMIT * 2,
        params_slice(:max_id, :since_id, :min_id)
      ))
      statuses = tag_timeline.paginate_by_id(
        limit_param(DEFAULT_STATUSES_LIMIT),
        params_slice(:max_id, :since_id, :min_id)
      )

      if truthy_param?(:only_media)
        # `SELECT DISTINCT id, updated_at` is too slow, so pluck ids at first, and then select id, updated_at with ids.
        status_ids = statuses.joins(:media_attachments).distinct(:id).pluck(:id)
        statuses.where(id: status_ids)
      else
        statuses
      end
    end
  end

  def tag_timeline_statuses
    HashtagQueryService.new.call(@tag, params.slice(:any, :all, :none), current_account, truthy_param?(:local))
  end

  def bookmark_results
    @_results ||= account_bookmarks.paginate_by_max_id(
      limit_param(DEFAULT_STATUSES_LIMIT),
      params[:max_id],
      params[:since_id]
    )
  end

  def account_bookmarks
    current_account.bookmarks
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def pagination_params(core_params)
    params.slice(:local, :limit, :only_media).permit(:local, :limit, :only_media).merge(core_params)
  end

  def next_path
    api_v1_timelines_tag_url params[:id], pagination_params(max_id: pagination_max_id)
  end

  def prev_path
    api_v1_timelines_tag_url params[:id], pagination_params(min_id: pagination_since_id)
  end

  def pagination_max_id
    @statuses.last.id
  end

  def pagination_since_id
    @statuses.first.id
  end

  def preload_media(statuses)
    status_ids = statuses.joins(:media_attachments).distinct(:id).select(:id).reorder(nil)
    fetch_ids = MediaAttachment.where(status_id: status_ids, file_updated_at: nil).pluck(:id)
    fetch_ids.each { |m| FetchMediaWorker.perform_async(m) }
  end
end
