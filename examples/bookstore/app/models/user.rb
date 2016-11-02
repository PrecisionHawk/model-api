class User < ActiveRecord::Base
  include ModelApi::Model

  has_many :orders, inverse_of: :user

  validates :email, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }

  api_attributes \
      id: { filter: true, sort: true, id: true },
      email: { filter: true, sort: true, id: true },
      first_name: { filter: true, sort: true },
      last_name: { filter: true, sort: true },
      admin: { alias: :administrator, filter: true, sort: true },
      created_at: { read_only: true, filter: true },
      updated_at: { read_only: true, filter: true }

end
