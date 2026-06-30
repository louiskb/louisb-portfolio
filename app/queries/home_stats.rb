# Computes the homepage "By the numbers" stats in one place so the view and
# tests share a single source of truth. Plain Ruby — Zeitwerk autoloads it from
# app/queries/home_stats.rb by its class name (no config needed).
#
# Usage: HomeStats.new.to_h
class HomeStats
  # ---------------------------------------------------------------------------
  # CONFIRM THESE, LOUIS: the two year stats below are derived from these start
  # years against the current year. Update them if either is off.
  #   - CODING_SINCE_YEAR: the year you started writing code in earnest.
  #   - TRADING_SINCE_YEAR: the year you started trading/markets (~6-year career).
  # ---------------------------------------------------------------------------
  CODING_SINCE_YEAR = 2024
  TRADING_SINCE_YEAR = 2018

  def to_h
    {
      projects_count: published_projects.count,
      blog_posts_count: BlogPost.published.count,
      technologies_count: technologies_count,
      years_coding: years_since(CODING_SINCE_YEAR),
      years_trading: years_since(TRADING_SINCE_YEAR)
    }
  end

  private

  def published_projects
    Project.published
  end

  # Distinct technologies across every published project's `tech_stack` string.
  # Each string is split on the canonical " . " (dot-space) separator the data is
  # authored with (seeds + the project form hint, e.g. "Vue.js . JavaScript . Vitest"),
  # stripped, blanks dropped, and de-duplicated case-insensitively (so "Rails" and
  # "rails" count once). Splitting on a bare "." would wrongly break "Vue.js".
  def technologies_count
    published_projects
      .pluck(:tech_stack)
      .compact
      .flat_map { |stack| stack.split(" . ") }
      .map { |tech| tech.strip.downcase }
      .reject(&:empty?)
      .uniq
      .size
  end

  # Whole years elapsed since `year`, floored at 0 so a future start year never
  # produces a negative count.
  def years_since(year)
    [Time.current.year - year, 0].max
  end
end
