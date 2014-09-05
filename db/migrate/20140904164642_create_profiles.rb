class CreateProfiles < ActiveRecord::Migration
  def change
    create_table :profiles do |t|
      t.string :role
      t.boolean :manage_users, default: false
      t.boolean :manage_profiles, default: false

      t.timestamps
    end
  end
end
