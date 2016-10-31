class CreateBookstore < ActiveRecord::Migration
  def change
    create_table :genres do |t|
      t.string :name, limit: 50, null: false
      t.timestamps
    end
    add_index :genres, :name, unique: true
    add_index :genres, :created_at
    add_index :genres, :updated_at

    create_table :authors do |t|
      t.string :display_name, null: false, limit: 100
      t.string :first_name, limit: 50
      t.string :last_name, limit: 50
      t.integer :primary_genre_id, null: false
      t.timestamps
    end
    add_index :authors, :display_name, unique: true
    add_index :authors, :first_name
    add_index :authors, :last_name
    add_index :authors, :primary_genre_id
    add_index :authors, :created_at
    add_index :authors, :updated_at

    create_table :author_genres do |t|
      t.integer :author_id
      t.integer :genre_id
      t.timestamps
    end
    add_index :author_genres, [:author_id, :genre_id], unique: true
    add_index :author_genres, :genre_id
    add_index :author_genres, :created_at
    add_index :author_genres, :updated_at

    create_table :author_books do |t|
      t.integer :author_id
      t.integer :book_id
      t.timestamps
    end
    add_index :author_books, [:author_id, :book_id], unique: true
    add_index :author_books, :book_id
    add_index :author_books, :created_at
    add_index :author_books, :updated_at

    create_table :books do |t|
      t.string :name, null: false, limit: 50
      t.string :description, limit: 250
      t.string :isbn, null: false, limit: 13
      t.decimal :price, null: false
      t.integer :primary_genre_id, null: false
      t.timestamps
    end
    add_index :books, :name
    add_index :books, :description
    add_index :books, :isbn, unique: true
    add_index :books, :price
    add_index :books, :primary_genre_id
    add_index :books, :created_at
    add_index :books, :updated_at

    create_table :other_products do |t|
      t.string :name, null: false, limit: 50
      t.string :description, limit: 250
      t.string :sku, null: false, limit: 50
      t.decimal :price, null: false
      t.timestamps
    end
    add_index :other_products, :name
    add_index :other_products, :description
    add_index :other_products, :sku, unique: true
    add_index :other_products, :price
    add_index :other_products, :created_at
    add_index :other_products, :updated_at

    create_table :book_genres do |t|
      t.integer :book_id
      t.integer :genre_id
      t.timestamps
    end
    add_index :book_genres, [:book_id, :genre_id], unique: true
    add_index :book_genres, :genre_id
    add_index :book_genres, :created_at
    add_index :book_genres, :updated_at

    create_table :users do |t|
      t.string :email, null: false, limit: 100
      t.string :first_name, null: false, limit: 50
      t.string :last_name, null: false, limit: 50
      t.datetime :last_login_at
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, [:last_name, :first_name]
    add_index :users, :first_name
    add_index :users, :last_login_at
    add_index :users, :created_at
    add_index :users, :updated_at

    create_table :orders do |t|
      t.integer :user_id, null: false
      t.string :status, null: false, limit: 50
      t.timestamps
    end
    add_index :orders, :user_id
    add_index :orders, :status
    add_index :orders, :created_at
    add_index :orders, :updated_at

    create_table :order_items do |t|
      t.integer :order_id, null: false
      t.string :item_type, null: false, limit: 100
      t.integer :item_id, null: false
      t.timestamps
    end
    add_index :order_items, [:order_id, :item_type, :item_id], unique: true
    add_index :order_items, [:item_type, :item_id]
    add_index :order_items, :created_at
    add_index :order_items, :updated_at
  end
end
