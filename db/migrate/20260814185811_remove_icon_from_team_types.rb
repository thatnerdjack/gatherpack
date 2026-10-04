class RemoveIconFromTeamTypes < ActiveRecord::Migration[8.1]
  def change
    remove_column :team_types, :icon, :string
  end
end
