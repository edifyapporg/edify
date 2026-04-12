module Noticed
  class EventResource < Madmin::Resource
    # Attributes
    attribute :id, form: false
    attribute :type, index: true
    attribute :record_type, index: true
    attribute :record_id, index: true
    attribute :params, form: false
    attribute :notifications_count, index: true
    attribute :created_at, form: false, index: true
    attribute :updated_at, form: false

    # Associations
    attribute :notifications

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
