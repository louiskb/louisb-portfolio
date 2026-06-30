class Project < ApplicationRecord
  include Publishable

  # Associations
  belongs_to :user

  # Validations
  validates :title, presence: true
  validates :description, presence: true
  validates :img_url, presence: true
  validates :tech_stack, presence: true
  validates :project_url, presence: true
  validates :user_id, presence: true
end
