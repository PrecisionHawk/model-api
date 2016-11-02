# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161031155516) do

  create_table "author_books", force: true do |t|
    t.integer "author_id"
    t.integer "book_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "author_books", ["author_id", "book_id"], name: "index_author_books_on_author_id_and_book_id", unique: true, using: :btree
  add_index "author_books", ["book_id"], name: "index_author_books_on_book_id", using: :btree
  add_index "author_books", ["created_at"], name: "index_author_books_on_created_at", using: :btree
  add_index "author_books", ["updated_at"], name: "index_author_books_on_updated_at", using: :btree

  create_table "author_genres", force: true do |t|
    t.integer "author_id"
    t.integer "genre_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "author_genres", ["author_id", "genre_id"], name: "index_author_genres_on_author_id_and_genre_id", unique: true, using: :btree
  add_index "author_genres", ["created_at"], name: "index_author_genres_on_created_at", using: :btree
  add_index "author_genres", ["genre_id"], name: "index_author_genres_on_genre_id", using: :btree
  add_index "author_genres", ["updated_at"], name: "index_author_genres_on_updated_at", using: :btree

  create_table "authors", force: true do |t|
    t.string "display_name", limit: 100, null: false
    t.string "first_name", limit: 50
    t.string "last_name", limit: 50
    t.integer "primary_genre_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "authors", ["created_at"], name: "index_authors_on_created_at", using: :btree
  add_index "authors", ["display_name"], name: "index_authors_on_display_name", unique: true, using: :btree
  add_index "authors", ["first_name"], name: "index_authors_on_first_name", using: :btree
  add_index "authors", ["last_name"], name: "index_authors_on_last_name", using: :btree
  add_index "authors", ["primary_genre_id"], name: "index_authors_on_primary_genre_id", using: :btree
  add_index "authors", ["updated_at"], name: "index_authors_on_updated_at", using: :btree

  create_table "book_genres", force: true do |t|
    t.integer "book_id"
    t.integer "genre_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "book_genres", ["book_id", "genre_id"], name: "index_book_genres_on_book_id_and_genre_id", unique: true, using: :btree
  add_index "book_genres", ["created_at"], name: "index_book_genres_on_created_at", using: :btree
  add_index "book_genres", ["genre_id"], name: "index_book_genres_on_genre_id", using: :btree
  add_index "book_genres", ["updated_at"], name: "index_book_genres_on_updated_at", using: :btree

  create_table "books", force: true do |t|
    t.string "name", limit: 50, null: false
    t.string "description", limit: 250
    t.string "isbn", limit: 13, null: false
    t.decimal "price", precision: 10, scale: 0, null: false
    t.integer "primary_genre_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "books", ["created_at"], name: "index_books_on_created_at", using: :btree
  add_index "books", ["description"], name: "index_books_on_description", using: :btree
  add_index "books", ["isbn"], name: "index_books_on_isbn", unique: true, using: :btree
  add_index "books", ["name"], name: "index_books_on_name", using: :btree
  add_index "books", ["price"], name: "index_books_on_price", using: :btree
  add_index "books", ["primary_genre_id"], name: "index_books_on_primary_genre_id", using: :btree
  add_index "books", ["updated_at"], name: "index_books_on_updated_at", using: :btree

  create_table "genres", force: true do |t|
    t.string "name", limit: 50, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "genres", ["created_at"], name: "index_genres_on_created_at", using: :btree
  add_index "genres", ["name"], name: "index_genres_on_name", unique: true, using: :btree
  add_index "genres", ["updated_at"], name: "index_genres_on_updated_at", using: :btree

  create_table "order_items", force: true do |t|
    t.integer "order_id", null: false
    t.string "item_type", limit: 100, null: false
    t.integer "item_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "order_items", ["created_at"], name: "index_order_items_on_created_at", using: :btree
  add_index "order_items", ["item_type", "item_id"], name: "index_order_items_on_item_type_and_item_id", using: :btree
  add_index "order_items", ["order_id", "item_type", "item_id"], name: "index_order_items_on_order_id_and_item_type_and_item_id", unique: true, using: :btree
  add_index "order_items", ["updated_at"], name: "index_order_items_on_updated_at", using: :btree

  create_table "orders", force: true do |t|
    t.integer "user_id", null: false
    t.string "status", limit: 50, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "orders", ["created_at"], name: "index_orders_on_created_at", using: :btree
  add_index "orders", ["status"], name: "index_orders_on_status", using: :btree
  add_index "orders", ["updated_at"], name: "index_orders_on_updated_at", using: :btree
  add_index "orders", ["user_id"], name: "index_orders_on_user_id", using: :btree

  create_table "other_products", force: true do |t|
    t.string "name", limit: 50, null: false
    t.string "description", limit: 250
    t.string "sku", limit: 50, null: false
    t.decimal "price", precision: 10, scale: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "other_products", ["created_at"], name: "index_other_products_on_created_at", using: :btree
  add_index "other_products", ["description"], name: "index_other_products_on_description", using: :btree
  add_index "other_products", ["name"], name: "index_other_products_on_name", using: :btree
  add_index "other_products", ["price"], name: "index_other_products_on_price", using: :btree
  add_index "other_products", ["sku"], name: "index_other_products_on_sku", unique: true, using: :btree
  add_index "other_products", ["updated_at"], name: "index_other_products_on_updated_at", using: :btree

  create_table "users", force: true do |t|
    t.string "email", limit: 100, null: false
    t.string "first_name", limit: 50, null: false
    t.string "last_name", limit: 50, null: false
    t.boolean "admin", default: false, null: false
    t.datetime "last_login_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["created_at"], name: "index_users_on_created_at", using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["first_name"], name: "index_users_on_first_name", using: :btree
  add_index "users", ["last_login_at"], name: "index_users_on_last_login_at", using: :btree
  add_index "users", ["last_name", "first_name"], name: "index_users_on_last_name_and_first_name", using: :btree
  add_index "users", ["updated_at"], name: "index_users_on_updated_at", using: :btree

end
