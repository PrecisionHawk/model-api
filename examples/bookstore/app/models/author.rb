class Author < ActiveRecord::Base
  include ModelApi::Model

  has_many :author_books, dependent: :destroy
  has_many :books, through: :author_books, inverse_of: :authors
  has_many :author_genres, dependent: :destroy
  has_many :genres, through: :author_genres, inverse_of: :authors
  belongs_to :primary_genre, class_name: 'Genre', inverse_of: :primary_authors

  validates :display_name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }
  validates :primary_genre, presence: true

  api_attributes \
      id: { filter: true, sort: true },
      display_name: { filter: true, sort: true },
      first_name: { filter: true, sort: true },
      last_name: { filter: true, sort: true },
      primary_genre: { filter: true, sort: true },
      created_at: { read_only: true, filter: true },
      updated_at: { read_only: true, filter: true }

end
