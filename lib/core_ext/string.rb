module CoreExt
  module String
    def numeric?
      true if Float(self)
    rescue StandardError
      false
    end
  end
end

class String
  include CoreExt::String
end
