class AddDiscardedAtToGrade < ActiveRecord::Migration
  def up
    add_column :grades, :discarded_at, :datetime
    add_index :grades, :discarded_at
  end

  def down
    remove_column :grades, :discarded_at
  end
end
