require "test_helper"

class PublishableTest < ActiveSupport::TestCase
  # Lightweight dummy model backed by a temporary table so the concern can be
  # tested in isolation, independent of BlogPost/Project.
  class PublishableThing < ApplicationRecord
    self.table_name = "publishable_things"
    include Publishable
  end

  setup do
    ActiveRecord::Base.connection.create_table :publishable_things, force: true do |t|
      t.integer :status, default: 2, null: false
      t.datetime :scheduled_at
      t.timestamps
    end
  end

  teardown do
    ActiveRecord::Base.connection.drop_table :publishable_things, if_exists: true
  end

  test "default status is published" do
    assert_equal "published", PublishableThing.new.status
  end

  test "status enum exposes draft, scheduled and published" do
    assert_equal({ "draft" => 0, "scheduled" => 1, "published" => 2 }, PublishableThing.statuses)
  end

  test "publish! marks the record published and clears scheduled_at" do
    thing = PublishableThing.create!(status: :scheduled, scheduled_at: 1.day.from_now)
    thing.publish!

    assert thing.published?
    assert_nil thing.scheduled_at
  end

  test "schedule! marks the record scheduled and stores the time" do
    time = 2.days.from_now
    thing = PublishableThing.create!(status: :draft)
    thing.schedule!(time)

    assert thing.scheduled?
    assert_in_delta time.to_i, thing.scheduled_at.to_i, 1
  end

  test "cancel_schedule! reverts to draft and clears scheduled_at" do
    thing = PublishableThing.create!(status: :scheduled, scheduled_at: 1.day.from_now)
    thing.cancel_schedule!

    assert thing.draft?
    assert_nil thing.scheduled_at
  end

  test "visible_to_visitors returns only published records" do
    draft = PublishableThing.create!(status: :draft)
    scheduled = PublishableThing.create!(status: :scheduled, scheduled_at: 1.day.from_now)
    published = PublishableThing.create!(status: :published)

    visible = PublishableThing.visible_to_visitors

    assert_includes visible, published
    assert_not_includes visible, draft
    assert_not_includes visible, scheduled
  end
end
