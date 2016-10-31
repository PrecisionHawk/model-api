class Order < ActiveRecord::Base
  include ModelApi::Model

  belongs_to :user
  has_many :order_items, inverse_of: :order

  validates :user, presence: true
  validates :status, presence: true,
      inclusion: { in: %w(new submitted processing shipping complete) }

  api_attributes \
      id: { filter: true, sort: true },
      user: { filter: true, sort: true },
      status: { filter: true, sort: true },
      created_at: { read_only: true, filter: true },
      updated_at: { read_only: true, filter: true }

end
