# to run this you'll need auth configured as described in docs on GoogleUserAuth in user_auth.rb
# and a spreadsheetId (change the one hardcoded below).
# then invoke, from scorpio's root, something like:
# GOOGLE_USER_ID=me@gmail.com
# GOOGLE_CLIENT_ID_JSON=~/secrets/client_secret_8848317-698khtn.apps.googleusercontent.com.json
# GOOGLE_TOKEN_STORE=~/secrets/client_secret_8848317-tokens.yml
# bundle exec ruby ./examples/google/sheets.rb

require('bundler/inline')

gemfile(install = true) do
  source('https://rubygems.org')
  gem('scorpio')
  gem('googleauth')
  gem('rackup')
  gem('webrick')
end

require('scorpio')
require_relative('user_auth')

module Sheets
  # this gets the sheets API rest description from the google discovery service.
  # for a real application this would normally cache the document locally.
  # e.g.: Scorpio::Google::RestDescription.new_jsi(JSON.parse(File.read('google-sheets-v4.json')))
  API = Scorpio::Google::DISCOVERY_REST_DESCRIPTION.resources['apis']['methods']['getRest'].run(
    api: "sheets",
    version: "v4",
  )

  # naming modules is not necessary but quite helpful in development/debugging
  API.schemas.each_pair do |name, schema|
    const_set(name, schema.jsi_schema_module) if name =~ /\A[A-Z]\w*\z/
  end

  extend(GoogleUserAuth)

  # scopes relevant to sheets:
  # https://www.googleapis.com/auth/drive                  See, edit, create, and delete all of your Google Drive files
  # https://www.googleapis.com/auth/drive.file             See, edit, create, and delete only the specific Google Drive files you use with this app
  # https://www.googleapis.com/auth/drive.readonly         See and download all your Google Drive files
  # https://www.googleapis.com/auth/spreadsheets           See, edit, create, and delete all your Google Sheets spreadsheets
  # https://www.googleapis.com/auth/spreadsheets.readonly  See all your Google Sheets spreadsheets
  self.scope = ['https://www.googleapis.com/auth/spreadsheets']

  API.faraday_builder = proc do |conn|
    conn.request(:google_user_auth_access_token, self)
  end
end


# here follows an example retrieving a spreadsheet and updating a range of values in it

spreadsheetId = '1ZLv-Yqz89zPdfj49t2TWdPnm4trqWsVDi6E6TwdzJsI'

pp(Sheets::API.operations["sheets.spreadsheets.get"].run(spreadsheetId: spreadsheetId))

range = 'A1:B2'

Sheets::API.operations["sheets.spreadsheets.values.clear"].run(
  spreadsheetId: spreadsheetId,
  range: range,
)

Sheets::API.operations["sheets.spreadsheets.values.update"].run(
  spreadsheetId: spreadsheetId,
  range: range,
  valueInputOption: 'RAW',
  includeValuesInResponse: false,
  body_object: {
    values: [['BB', 'Bb'], ['Bb', 'bb']],
  }
)
