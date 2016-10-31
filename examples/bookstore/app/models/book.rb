class Book < ActiveRecord::Base
  include ModelApi::Model

  has_many :book_genres, dependent: :destroy
  has_many :genres, through: :book_genres, inverse_of: :books
  has_many :author_books, dependent: :destroy
  has_many :authors, through: :author_books, inverse_of: :books
  belongs_to :primary_genre, class_name: 'Genre', inverse_of: :primary_books

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :description, length: { maximum: 250 }
  validates :isbn, presence: true, uniqueness: true, length: { maximum: 13 }

  api_attributes \
      id: { filter: true, sort: true },
      name: { filter: true, sort: true },
      description: {},
      isbn: { filter: true, sort: true,
          parse: ->(v) { v.to_s.gsub(%r{[^\d]+}, '') },
          render: ->(v) { "#{v[0..2]}-#{v[3]}-#{v[4..5]}-#{v[6..11]}-#{v[12..-1]}" }
      },
      created_at: { read_only: true, filter: true },
      updated_at: { read_only: true, filter: true }

end
