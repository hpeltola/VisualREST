# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_visualrest_session',
  :secret      => 'd718b03a736a541ca24548f44100551da89059d95834bc5f4b46ba210e4a45bc5bb7077f3e514281a8c376e87c72a9e343e6bca18e669cd14b0926f57459d8f1'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
