# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_icpserver_session',
  :secret      => 'be480958758ee8bdfb807125817a2d71b3ca2163167e933a93761441c4778326a3eb2cf75d593e0d11f245c34ceb4736483c8d65196a28c941e17c6ac90895e5'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
