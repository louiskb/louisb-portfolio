class BlogPostsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :load_tags, only: %i[ new edit create update ]
  before_action :set_ai_blog_post, only: %i[ ai_revise revise_with_ai ]
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
    @blog_post = BlogPost.new(blog_post_params)
    @blog_post.user = current_user

    if @blog_post.save
      redirect_to blog_post_path(@blog_post), notice: "Blog post was successfully created!"
    else
      render "new", alert: "Blog post failed to create. Please try again!", status: :unprocessable_entity
    end
  end

  def edit
    @blog_post = BlogPost.friendly.find(params[:id])
  end

  def update
    @blog_post = BlogPost.friendly.find(params[:id])

    if @blog_post.update(blog_post_params)
      redirect_to blog_post_path(@blog_post), notice: "Blog post was successfully edited!"
    else
      render :edit, status: :unprocessable_entity
    end
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

  def set_ai_blog_post
    @blog_post = BlogPost.friendly.find(params[:id])
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
