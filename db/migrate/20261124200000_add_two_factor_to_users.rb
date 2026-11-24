class AddTwoFactorToUsers < ActiveRecord::Migration[8.1]
  # Columns for two-factor sign-in (#392). two_factor_method is the user's second factor: 0 for none, 1 for an emailed
  # confirmation (a link or a code), 2 for codes from an authenticator app (devise-two-factor, which asks the model for
  # otp_required_for_login; User will answer from this column). Authenticator apps are required for admins.
  #
  # For authenticator apps: otp_secret holds the TOTP secret, encrypted with Active Record encryption;
  # consumed_timestep records the last code used, so a code can't be replayed; otp_backup_codes holds bcrypt digests
  # of one-time recovery codes.
  def change
    change_table :users, bulk: true do |t|
      t.integer :two_factor_method, null: false, default: 0
      t.string :otp_secret
      t.integer :consumed_timestep
      t.string :otp_backup_codes, array: true
    end
  end
end
