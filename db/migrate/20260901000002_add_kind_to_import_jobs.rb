class AddKindToImportJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :import_jobs, :kind, :integer, null: false, default: 0

    reversible do |direction|
      direction.up { execute "UPDATE import_jobs SET kind = 0" } # every existing job imported individuals
    end
  end
end
