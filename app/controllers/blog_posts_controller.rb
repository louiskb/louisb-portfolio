class BlogPostsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  def index
    @blog_posts = BlogPost.all
  end

  def show
    @blog_post = BlogPost.friendly.find(params[:id])
  end

  # PATCH /blog_posts/reorder — persists drag-and-drop order (owner only).
  def reorder
    reorder_params.fetch(:ids, []).each_with_index do |id, index|
      BlogPost.where(id: id).update_all(position: index)
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

  private

  def blog_post_params
    params.require(:blog_post).permit(:title, :description, :img_url, :tags, :html_content, :user_id)
  end

  def reorder_params
    params.permit(ids: [])
  end
end
