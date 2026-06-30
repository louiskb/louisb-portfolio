class BlogPostsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :load_tags, only: %i[ new edit create update ]
  before_action :set_ai_blog_post, only: %i[ ai_revise revise_with_ai ]
  before_action :set_owned_blog_post, only: %i[ publish schedule cancel_schedule ]
  # The POST/PATCH actions actually call Claude, so guard them up front. The GET
  # forms render fine without a key (the view shows a "configure" notice).
  before_action :require_ai_configured, only: %i[ create_with_ai revise_with_ai ]

  def index
    # Owner sees everything; visitors only see published posts.
    scope = user_signed_in? ? BlogPost.all : BlogPost.visible_to_visitors

    # Title search (case-insensitive).
    if params[:q].present?
      scope = scope.where("title ILIKE ?", "%#{params[:q].strip}%")
    end

    # Tag filter — match posts carrying any of the selected tags.
    if params[:tag_ids].present?
      tag_ids = Array(params[:tag_ids]).map(&:to_i).select(&:positive?)
      scope = scope.joins(:tags).where(tags: { id: tag_ids }).distinct if tag_ids.any?
    end

    @all_tags = Tag.order(:name)
    # Keep :position ordering so the Phase-1 drag-to-reorder stays meaningful.
    @pagy, @blog_posts = pagy(scope.order(:position))
  end

  def show
    @blog_post = BlogPost.friendly.find(params[:id])

    track_event("blog_post_viewed", {
      title: @blog_post.title,
      slug: @blog_post.slug,
      tags: @blog_post.tags.pluck(:name),
      ai_generated: @blog_post.ai_generated?
    })
  end

  # PATCH /blog_posts/reorder — persists drag-and-drop order (owner only).
  # Scoped to current_user.blog_posts so a request can only reorder records it
  # owns (defense-in-depth IDOR guard, even though this is a single-user app).
  def reorder
    reorder_params.fetch(:ids, []).map(&:to_i).each_with_index do |id, index|
      current_user.blog_posts.where(id: id).update_all(position: index)
    end
    head :ok
  end

  def new
    @blog_post = BlogPost.new
  end

  def create
    status, scheduled_at = resolve_publish_intent(
      params.dig(:blog_post, :status),
      params.dig(:blog_post, :scheduled_at)
    )
    @blog_post = BlogPost.new(blog_post_params.merge(status: status, scheduled_at: scheduled_at))
    @blog_post.user = current_user

    if @blog_post.save
      redirect_to blog_post_path(@blog_post), notice: publish_notice(status, scheduled_at, action: :created)
    else
      render "new", alert: "Blog post failed to create. Please try again!", status: :unprocessable_entity
    end
  end

  def edit
    @blog_post = BlogPost.friendly.find(params[:id])
  end

  def update
    @blog_post = BlogPost.friendly.find(params[:id])
    status, scheduled_at = resolve_publish_intent(
      params.dig(:blog_post, :status),
      params.dig(:blog_post, :scheduled_at)
    )

    if @blog_post.update(blog_post_params.merge(status: status, scheduled_at: scheduled_at))
      redirect_to blog_post_path(@blog_post), notice: publish_notice(status, scheduled_at, action: :updated)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # PATCH /blog_posts/:id/publish — publishes a draft or scheduled post now.
  def publish
    @blog_post.publish!
    redirect_to blog_post_path(@blog_post), notice: "Post published successfully."
  end

  # PATCH /blog_posts/:id/schedule — sets a future publish time.
  def schedule
    parsed_time = parse_future_time(params[:scheduled_at])

    if parsed_time.nil?
      redirect_to blog_post_path(@blog_post),
        alert: "Please choose a date and time in the future to schedule."
      return
    end

    @blog_post.schedule!(parsed_time)
    redirect_to blog_post_path(@blog_post),
      notice: "Post scheduled for #{parsed_time.strftime("%d %b %Y at %H:%M")}."
  end

  # PATCH /blog_posts/:id/cancel_schedule — reverts a scheduled post to draft.
  def cancel_schedule
    @blog_post.cancel_schedule!
    redirect_to blog_post_path(@blog_post), notice: "Schedule cancelled. Post reverted to draft."
  end

  def destroy
    @blog_post = BlogPost.friendly.find(params[:id])

    if @blog_post.destroy
      redirect_to blog_posts_path, notice: "Blog post was successfully deleted!", status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  # GET /blog_posts/ai_new — renders the AI creation prompt form (or a
  # "configure ANTHROPIC_API_KEY" notice when the key is absent).
  def ai_new
  end

  # POST /blog_posts/create_with_ai — generates a new post via the AI service.
  def create_with_ai
    status = (ai_params[:status].presence || "draft").to_sym

    service = BlogPostAiService.new(current_user)
    @blog_post = service.create_from_prompt(
      ai_params[:prompt],
      featured_image: ai_params[:featured_image],
      image_url: ai_params[:image_url],
      status: status,
      scheduled_at: ai_params[:scheduled_at]
    )

    if @blog_post.persisted?
      redirect_to blog_post_path(@blog_post), notice: "Blog post created with AI."
    else
      flash.now[:alert] = "The AI response couldn't be saved: #{@blog_post.errors.full_messages.to_sentence}"
      @prompt = ai_params[:prompt]
      render :ai_new, status: :unprocessable_entity
    end
  rescue StandardError => e
    handle_ai_error(e, :ai_new)
  end

  # GET /blog_posts/:id/ai_revise — renders the AI revision form.
  def ai_revise
    @has_rich_text_body = @blog_post.body.present?
  end

  # PATCH /blog_posts/:id/revise_with_ai — revises an existing post via the AI service.
  def revise_with_ai
    status = ai_params[:status].present? ? ai_params[:status].to_sym : nil
    keep = ai_params[:keep_featured_image] == "1"

    service = BlogPostAiService.new(current_user)
    @blog_post = service.revise_blog_post(
      @blog_post,
      ai_params[:prompt],
      featured_image: ai_params[:featured_image],
      image_url: ai_params[:image_url],
      keep_featured_image: keep,
      status: status,
      scheduled_at: ai_params[:scheduled_at]
    )

    if @blog_post.persisted? && @blog_post.errors.empty?
      redirect_to blog_post_path(@blog_post), notice: "Blog post revised with AI."
    else
      flash.now[:alert] = "The AI revision couldn't be saved: #{@blog_post.errors.full_messages.to_sentence}"
      @prompt = ai_params[:prompt]
      @has_rich_text_body = @blog_post.body.present?
      render :ai_revise, status: :unprocessable_entity
    end
  rescue StandardError => e
    handle_ai_error(e, :ai_revise)
  end

  private

  # Scoped to current_user.blog_posts so a revision request can only target a
  # post the signed-in owner owns (defense-in-depth IDOR guard).
  def set_ai_blog_post
    @blog_post = current_user.blog_posts.friendly.find(params[:id])
  end

  # Scoped to current_user.blog_posts so a publish/schedule/cancel request can
  # only act on a post the signed-in owner owns (defense-in-depth IDOR guard,
  # matching the reorder/set_ai_blog_post pattern).
  def set_owned_blog_post
    @blog_post = current_user.blog_posts.friendly.find(params[:id])
  end

  # Parses the split button's status + datetime-local scheduled_at into the
  # [status_symbol, scheduled_at_or_nil] pair persisted on the record.
  #
  #   "published"                       -> publish now
  #   "scheduled" + future scheduled_at -> schedule
  #   "scheduled" + blank/past time     -> draft  (safer than silently publishing)
  #   "draft" / anything else           -> draft
  def resolve_publish_intent(raw_status, raw_scheduled_at)
    status = (raw_status.presence || "draft").to_sym

    if status == :scheduled
      parsed = parse_future_time(raw_scheduled_at)
      return [ :draft, nil ] if parsed.nil?

      return [ :scheduled, parsed ]
    end

    [ status, nil ]
  end

  # Returns a parsed Time only when the input is present and strictly in the
  # future; otherwise nil. Tolerates unparseable input (returns nil).
  def parse_future_time(raw)
    return nil if raw.blank?

    parsed = Time.zone.parse(raw.to_s)
    parsed if parsed && parsed > Time.current
  rescue ArgumentError
    nil
  end

  # Human-readable flash notice describing what happened to the post.
  def publish_notice(status, scheduled_at, action:)
    base = action == :created ? "Blog post saved" : "Blog post updated"

    case status.to_sym
    when :published then "#{base} and published."
    when :scheduled then "#{base} and scheduled for #{scheduled_at.strftime("%d %b %Y at %H:%M")}."
    else                 "#{base} as draft."
    end
  end

  # Redirects to the blog with a friendly notice when AI is not configured, so
  # the generate/revise endpoints degrade gracefully instead of erroring.
  def require_ai_configured
    return if helpers.ai_configured?

    redirect_to blog_posts_path,
      alert: "AI features need an ANTHROPIC_API_KEY. Set it to enable AI blog generation."
  end

  def ai_params
    params.require(:blog_post).permit(:prompt, :featured_image, :image_url,
                                      :keep_featured_image, :status, :scheduled_at)
  end

  # Logs the failure and re-renders the AI form with a generic, non-leaky alert.
  def handle_ai_error(error, render_action)
    Rails.logger.error "AI error in BlogPostsController: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if error.backtrace
    flash.now[:alert] = "The AI encountered an error. Please try again."
    @prompt = begin
      ai_params[:prompt]
    rescue StandardError
      nil
    end
    @has_rich_text_body = @blog_post&.body&.present?
    render render_action, status: :unprocessable_entity
  end

  def blog_post_params
    params.require(:blog_post).permit(:title, :description, :img_url, :html_content, :body,
                                      :blog_excerpt, :featured_image_caption, :user_id,
                                      :featured_image, :featured, :status, :scheduled_at, :position,
                                      tag_ids: [], photos: [])
  end

  def load_tags
    @all_tags = Tag.order(:name)
  end

  def reorder_params
    params.permit(ids: [])
  end
end
