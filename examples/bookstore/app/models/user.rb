class Author < ActiveRecord::Base
  include ModelApi::Model

  belongs_to :primary_genre, class_name: 'Genre'

  has_many :orders, inverse_of: :user

  validates :email, presence: true, unique: true, length: { maximum: 100 }
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }

  api_attributes \
      id: { filter: true, sort: true },
      email: { filter: true, sort: true },
      first_name: { filter: true, sort: true },
      last_name: { filter: true, sort: true },
      created_at: { read_only: true, filter: true },
      updated_at: { read_only: true, filter: true }

end
