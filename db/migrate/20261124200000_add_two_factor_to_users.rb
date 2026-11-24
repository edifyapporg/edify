class AddTwoFactorToUsers < ActiveRecord::Migration[8.1]
  # Columns for devise-two-factor (#392): sign-in codes from an authenticator app, required for admins and optional
  # for leaders. otp_secret holds the TOTP secret, encrypted with Active Record encryption. consumed_timestep records
  # the last code used, so a code can't be replayed. otp_backup_codes holds bcrypt digests of one-time recovery codes.
  def change
    change_table :users, bulk: true do |t|
      t.string :otp_secret
      t.integer :consumed_timestep
      t.boolean :otp_required_for_login, null: false, default: false
      t.string :otp_backup_codes, array: true
    end
  end
end
