require "test_helper"

# Covers the modal-driven team flow: the frame-aware new/show/edit renders and
# the turbo stream responses that refresh a card in place.
#
# The shared fixture set currently fails to load (several .yml files still list
# columns that have since been dropped), which errors out every test that
# touches it. This case builds the handful of records it needs instead, so it
# runs regardless of that.
class TeamsModalTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  FRAME_HEADER = { "Turbo-Frame" => "team_modal" }.freeze

  setup do
    @admin = User.create!(email: "modal-admin@example.com", password: "password123")
    @admin.update!(admin: true)
    Person.create!(user: @admin, first_name: "Ada", last_name: "Admin", display_name: "Ada Admin")

    @team_type = TeamType.create!(name: "Scouts")
    @team = Team.create!(name: "Pack 42", color: "#f5c211", team_type: @team_type)

    sign_in @admin
  end

  teardown do
    Membership.delete_all
    Team.delete_all
    TeamType.delete_all
    Person.delete_all
    User.delete_all
  end

  # --- frame-aware renders -------------------------------------------------

  test "new renders the modal form for a frame request" do
    get new_team_url, headers: FRAME_HEADER

    assert_response :success
    assert_select "turbo-frame#team_modal"
    assert_select "turbo-frame#team_modal .modal-footer button", text: /Create Team/
    assert_select ".tag-select-option", text: "Scouts"
  end

  test "new still renders the full page outside a frame" do
    get new_team_url

    assert_response :success
    assert_select "turbo-frame#team_modal", false
    assert_select "h1", text: "New team"
  end

  test "show renders read-only modal details for a frame request" do
    get team_url(@team), headers: FRAME_HEADER

    assert_response :success
    assert_select "turbo-frame#team_modal .modal-title", text: /Pack 42/
    assert_select ".modal-footer a", text: "Open Team Page"
    assert_select ".modal-footer a", text: /Edit/
    assert_select "form", false, "details view should be read only"
  end

  test "show still renders the full team page outside a frame" do
    get team_url(@team)

    assert_response :success
    assert_select "turbo-frame#team_modal", false
    assert_select "h1", text: /Pack 42/
  end

  test "edit renders the modal form for a frame request" do
    get edit_team_url(@team), headers: FRAME_HEADER

    assert_response :success
    assert_select "turbo-frame#team_modal .modal-title", text: /Editing Pack 42/
    assert_select ".tag-select-option.active", false, "selection is applied client side"
  end

  # --- create --------------------------------------------------------------

  test "modal create answers with a turbo stream that prepends the card" do
    assert_difference("Team.count", 1) do
      post teams_url, params: { modal: "1", team: { name: "Trail Blazers", color: "#3584e4", team_type_id: @team_type.id } }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match %r{<turbo-stream action="prepend" target="teams">}, response.body
    assert_match "Trail Blazers", response.body
    assert_match %r{<turbo-stream action="prepend" target="flash-messages">}, response.body
  end

  test "non-modal create still redirects to the team" do
    post teams_url, params: { team: { name: "Trail Blazers", color: "#3584e4", team_type_id: @team_type.id } }

    assert_redirected_to team_url(Team.find_by(name: "Trail Blazers"))
  end

  test "modal create builds a team type named in the tag picker" do
    assert_difference([ "Team.count", "TeamType.count" ], 1) do
      post teams_url, params: { modal: "1", team: { name: "Trail Blazers", color: "#3584e4", new_team_type_name: "Adventure Crew" } }
    end

    assert_equal "Adventure Crew", Team.find_by(name: "Trail Blazers").team_type.name
  end

  test "a named team type is matched case-insensitively instead of duplicated" do
    assert_no_difference "TeamType.count" do
      post teams_url, params: { modal: "1", team: { name: "Trail Blazers", color: "#3584e4", new_team_type_name: "scouts" } }
    end

    assert_equal @team_type, Team.find_by(name: "Trail Blazers").team_type
  end

  test "a team that fails validation leaves no stray team type behind" do
    assert_no_difference [ "Team.count", "TeamType.count" ] do
      post teams_url, params: { modal: "1", team: { name: "", new_team_type_name: "Adventure Crew" } }
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame#team_modal", 1, "the modal re-renders in place with its errors"
  end

  test "someone who cannot manage team types cannot create one through the picker" do
    manager = User.create!(email: "modal-manager@example.com", password: "password123")
    person = Person.create!(user: manager, first_name: "Mo", last_name: "Manager", display_name: "Mo Manager")
    Membership.create!(team: @team, person: person, manager: true)
    sign_in manager

    assert_no_difference "TeamType.count" do
      post teams_url, params: { modal: "1", team: { name: "Sub Team", parent_id: @team.id, new_team_type_name: "Sneaky Type" } }
    end
  end

  # --- update --------------------------------------------------------------

  test "modal update answers with a turbo stream that replaces the card" do
    patch team_url(@team), params: { modal: "1", team: { name: "Pack 43" } }

    assert_response :success
    assert_equal "Pack 43", @team.reload.name
    assert_match %r{<turbo-stream action="replace" target="team_#{@team.id}">}, response.body
    assert_match "Pack 43", response.body
  end

  test "non-modal update still redirects to the team" do
    patch team_url(@team), params: { team: { name: "Pack 43" } }

    assert_redirected_to team_url(@team)
  end

  test "modal update re-renders the form when validation fails" do
    patch team_url(@team), params: { modal: "1", team: { name: "" } }

    assert_response :unprocessable_entity
    assert_select "turbo-frame#team_modal", 1
    assert_equal "Pack 42", @team.reload.name
  end

  # --- destroy -------------------------------------------------------------

  test "modal destroy answers with a turbo stream that removes the card" do
    stream_target = "team_#{@team.id}"

    assert_difference("Team.count", -1) do
      delete team_url(@team, modal: "1")
    end

    assert_response :success
    assert_match %r{<turbo-stream action="remove" target="#{stream_target}">}, response.body
  end

  test "non-modal destroy still redirects to the index" do
    delete team_url(@team)

    assert_redirected_to teams_url
  end
end
