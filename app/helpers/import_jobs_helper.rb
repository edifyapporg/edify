module ImportJobsHelper
  # The choices on the import form: one per Member Directory tab, plus both together. The description is what tells
  # someone they copied the right tab.
  IMPORT_KIND_OPTIONS = [
    ["individuals", "Individuals", "Names, genders, birthdates and contact details."],
    ["households", "Households", "Who lives together, and the family contact details."],
    ["both", "Individuals + Households", "Both tabs at once. Individuals are imported first, then Households."],
  ].freeze

  def import_kind_options
    IMPORT_KIND_OPTIONS
  end
end
