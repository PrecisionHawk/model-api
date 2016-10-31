class Book < ActiveRecord::Base
  include ModelApi::Model

  validates :other_product, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :description, length: { maximum: 250 }
  validates :sku, presence: true, uniqueness: true, length: { maximum: 50 }

  api_attributes \
      id: { filter: true, sort: true },
      name: { filter: true, sort: true },
      description: {},
      sku: { filter: true, sort: true },
      created_at: { read_only: true, filter: true },
      updated_at: { read_only: true, filter: true }

end
