module Analytics
  class EmailEventResource < Madmin::Resource
    # Attributes
    attribute :id, form: false, index: true
    attribute :email, index: true
    attribute :timestamp, index: true
    attribute :smtp_id, index: false
    attribute :event, index: true
    attribute :type, index: true
    attribute :category, index: false
    attribute :provider_event_id, index: false
    attribute :provider_message_id, index: false
    attribute :reason, index: false
    attribute :status
    attribute :ip, index: false
    attribute :response, index: false
    attribute :event_type, index: false
    attribute :useragent, index: false
    attribute :created_at, form: false, index: true
    attribute :updated_at, form: false, index: false

    # Associations

    # Uncomment this to customize the display name of records in the admin area.
    # def self.display_name(record)
    #   record.name
    # end

    def self.default_sort_column
      "created_at"
    end

    def self.default_sort_direction
      "desc"
    end
  end
end
