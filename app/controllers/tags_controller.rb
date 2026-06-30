class TagsController < ApplicationController
  before_action :authenticate_user!

  # POST /tags (JSON) — creates a tag from the inline tag manager in the blog
  # post form. The Tag model normalises capitalisation before saving.
  def create
    name = params.dig(:tag, :name).to_s.strip

    if name.blank?
      render json: { error: "Name can't be blank" }, status: :unprocessable_entity
      return
    end

    @tag = Tag.where("LOWER(name) = ?", name.downcase).first || Tag.new(name: name)

    if @tag.persisted? || @tag.save
      render json: { id: @tag.id, name: @tag.name }, status: :ok
    else
      render json: { error: @tag.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  # DELETE /tags/:id (JSON) — deletes a tag globally (removes it from all posts).
  def destroy
    @tag = Tag.find(params[:id])
    @tag.destroy!
    head :no_content
  end
end
