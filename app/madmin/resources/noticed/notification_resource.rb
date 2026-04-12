module Noticed
  class NotificationResource < Madmin::Resource
    # Attributes
    attribute :id, form: false
    attribute :type, index: true
    attribute :read_at, index: true
    attribute :seen_at, index: true
    attribute :created_at, form: false, index: true
    attribute :updated_at, form: false

    # Associations
    attribute :event, index: true
    attribute :recipient, index: true

    def self.display_name(record)
      "#{record.type} ##{record.id}"
    end

    def self.default_sort_column
      "created_at"
    end

    def self.default_sort_direction
      "desc"
    end
  end
end
