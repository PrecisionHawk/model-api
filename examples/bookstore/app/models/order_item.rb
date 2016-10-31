class OrderItem < ActiveRecord::Base
  include ModelApi::Model

  belongs_to :order, inverse_of: :order_items
  belongs_to :item, polymorphic: true

  validates :order, presence: true
  validates :item, presence: true

  api_attributes \
      id: { filter: true, sort: true },
      item: { filter: true, sort: true },
      created_at: { read_only: true, filter: true },
      updated_at: { read_only: true, filter: true }

end
