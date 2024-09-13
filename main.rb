require "sequel"
require "securerandom"

$stdout.sync = true

db_name = SecureRandom.hex
system("createdb", db_name)

puts "Creted database: #{db_name}"

begin
  db = Sequel.connect("postgres://localhost/#{db_name}")
  db.create_table(:passwords) do
    column :encrypted_password, :bytea
  end

  ENCRYPTION_KEY = SecureRandom.alphanumeric(32).freeze

  puts "Encryption key: #{ENCRYPTION_KEY}"

  class Password < Sequel::Model
    plugin :column_encryption do |enc|
      enc.key 0, ENCRYPTION_KEY
      enc.column :encrypted_password
    end
  end

  Password.create(encrypted_password: "test")

  puts "Sequel result: #{Password.first.encrypted_password}"

  # This fails beacuse pgcrypto does not support aes-256-gcm
  # raw_query = <<~SQL
  #   SELECT pgp_sym_decrypt(encrypted_password, :key) AS password FROM passwords LIMIT 1;
  # SQL
  # result = db[raw_query, key: ENCRYPTION_KEY]
  # puts "Raw result: #{result[:password]}"

  keys = [[0, ENCRYPTION_KEY, "", Sequel::Plugins::ColumnEncryption::Cryptor::DEFAULT_PADDING]]
  cryptor = Sequel::Plugins::ColumnEncryption::Cryptor.new(keys)
  password = cryptor.decrypt(Password.first[:encrypted_password])
  puts password
ensure
  db.disconnect
  system("dropdb", db_name)
end
