class Book < ActiveRecord::Base
  include ModelApi::Model

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
