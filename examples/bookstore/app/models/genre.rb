class Genre < ActiveRecord::Base
  include ModelApi::Model

  has_many :author_genres, dependent: :destroy
  has_many :authors, through: :author_genres, inverse_of: :genres
  has_many :primary_authors, class_name: 'Author', inverse_of: :primary_genre,
      foreign_key: :primary_genre_id

  has_many :book_genres, dependent: :destroy
  has_many :books, through: :book_genres, inverse_of: :genres
  has_many :primary_books, class_name: 'Book', inverse_of: :primary_genre,
      foreign_key: :primary_genre_id

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }

  api_attributes \
      id: { filter: true, sort: true, id: true },
      name: { filter: true, sort: true, id: true },
      created_at: { read_only: true, filter: true },
      updated_at: { read_only: true, filter: true }

end
