module ImportJobsHelper
  # The choices on the import form: one per Member Directory tab, plus both together. The description is what tells
  # someone they copied the right tab.
  def import_kind_options
    [
      ["individuals", "Individuals", "Names, genders, birthdates and contact details."],
      ["households", "Households", "Who lives together, and the family contact details."],
      ["both", "Individuals + Households", "Both tabs at once. Individuals are imported first, then Households."],
    ]
  end
end
