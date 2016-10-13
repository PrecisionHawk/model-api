class CreateBooks < ActiveRecord::Migration
  def change
    create_table :books do |t|
      t.string :name, limit: 50, null: false
      t.string :description, limit: 250
      t.string :isbn, limit: 13
      t.timestamps
    end

    add_index :books, :name, unique: true
    add_index :books, :description
    add_index :books, :isbn, unique: true
    add_index :books, :created_at
    add_index :books, :updated_at
  end
end
