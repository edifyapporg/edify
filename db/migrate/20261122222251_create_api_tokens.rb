class CreateApiTokens < ActiveRecord::Migration[8.1]
  # Personal access tokens for the API, CLI and MCP endpoint (#315). Only a digest of each token is stored; the
  # plaintext is shown to the user once at creation and never persisted. `expires_at` and `revoked_at` are nullable:
  # a token with no expiry lasts until revoked, and a revoked row is kept so the settings page can show its history.
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :expires_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :api_tokens, :token_digest, unique: true
  end
end
