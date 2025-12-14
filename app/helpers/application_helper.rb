module ApplicationHelper
  def nav_link_class(path = "#")
    current_page?(path) ? "nav-link active fs-5" : "nav-link fs-5"
  end

  def nav_link_dropdown_class(path = "#")
    current_page?(path) ? "dropdown-item active fs-5" : "dropdown-item fs-5"
  end
end
