module TeamsHelper
  def team_as_badge(team, **opts)
    content = if opts[:small]
      i(team.identifier_icon)
    else
      i(team.identifier_icon) + " " + team.name
    end
    tag.span content, class: "badge", style: "background-color: #{team.display_color}; color: #{contrasting_color(team.display_color)}"
  end
end
