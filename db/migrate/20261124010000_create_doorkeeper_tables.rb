class CreateDoorkeeperTables < ActiveRecord::Migration[8.1]
  # Tables for Doorkeeper, the OAuth authorization server that lets Claude connect to the MCP endpoint with a leader's
  # sign-in instead of a pasted token (#323). Based on Doorkeeper 5.9's generator, with its PKCE and refresh-token
  # rotation columns, and these choices:
  #
  # - `oauth_applications.secret` is nullable: Claude registers through a Client ID Metadata Document as a public
  #   client, which has no secret.
  # - `oauth_applications.metadata_fetched_at` records when that client's metadata document was last fetched, so it
  #   can be refreshed rather than trusted forever.
  # - Grants and tokens reference `users` with cascading deletes, so removing a user removes their authorizations.
  #
  # Nothing uses these tables until the Doorkeeper setup ships, so this is safe with the deployed code.
  def change
    create_table :oauth_applications do |t|
      t.string :name, null: false
      t.string :uid, null: false
      t.string :secret
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.boolean :confidential, null: false, default: true
      t.datetime :metadata_fetched_at
      t.timestamps
    end

    add_index :oauth_applications, :uid, unique: true

    # Doorkeeper's own shape: grants and tokens are never updated after creation except to set revoked_at.
    create_table :oauth_access_grants do |t|
      t.references :resource_owner, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :application, null: false, foreign_key: { to_table: :oauth_applications }
      t.string :token, null: false
      t.integer :expires_in, null: false
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.string :code_challenge
      t.string :code_challenge_method
      t.datetime :created_at, null: false
      t.datetime :revoked_at
    end

    add_index :oauth_access_grants, :token, unique: true

    create_table :oauth_access_tokens do |t|
      t.references :resource_owner, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :application, null: false, foreign_key: { to_table: :oauth_applications }
      t.string :token, null: false
      t.string :refresh_token
      t.integer :expires_in
      t.string :scopes
      t.datetime :created_at, null: false
      t.datetime :revoked_at
      # With this column, Doorkeeper revokes a refresh token only once the access token issued in exchange for it
      # is first used, so a client that loses the refresh response can retry.
      t.string :previous_refresh_token, null: false, default: ""
    end

    add_index :oauth_access_tokens, :token, unique: true
    add_index :oauth_access_tokens, :refresh_token, unique: true
  end
end
