#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.
require 'resque/tasks'

require File.expand_path('../config/application', __FILE__)

TransformersWeb::Application.load_tasks

task :'fetch-css-property-index' do
  # Ok, this is not much useful now. I manually typed out values for initial value from
  # w3.org.
  require 'nokogiri'
  require 'open-uri'
  require 'pp'

  # This currently has a property list from CSS2, which covers most of the cases, will 
  # update it with a CSS3 property index later.
  doc = Nokogiri::HTML(open('http://www.w3.org/TR/CSS/'))

  property_index = {}

  doc.css('.proptable tbody tr').each do |property_row|
    property_row.css('th code').each do |property|
      inherit = property_row.css('td')[3].inner_text.strip == 'yes' ? true : false 
      # Make it a hash so that in case we want to add more properties to it.
      property_index[property.inner_text.to_sym] = { :inherit => inherit }
    end
  end

  f = File.open(Rails.root.join('db', 'json', 'css', 'css_properties.json'), 'w+')
  f.write JSON.pretty_generate(property_index)
  f.close

  JSON.pretty_generate(property_index)
end