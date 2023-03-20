#!/usr/bin/env ruby
require 'bundler/setup'
require 'csv'
require 'bigdecimal'
require_relative 'us_states'

orig_data_path = 'data/orig'
parsed_data_path = 'data/parsed'

CSV.open("#{parsed_data_path}/risk.csv", 'w') do |csv|
  csv << ["ID", "County","State","Heat","Wet Bulb","Farm Crop Yields","Sea Level Rise","Very Large Fires","Economic Damages","Total Risk Score"]
  CSV.read("#{orig_data_path}/risk.csv", headers: true).each do |row|
    county_and_state = row.fetch('County')
    county, state_abbr = county_and_state.split(',')
    county.strip!
    state_abbr.strip!
    original_row = row.to_h.values
    data = original_row.slice(1, original_row.length)
    id = "#{state_abbr} - #{county}"
    csv << [id, county, state_abbr] + data
  end
end


CSV.open("#{parsed_data_path}/home_prices.csv", 'w') do |csv|
  csv << ["ID", "County","State","Median Price"]
  CSV.read("#{orig_data_path}/home_prices.csv", headers: true).each do |row|
    county = row.fetch('County')
    state_abbr = row.fetch('State Abbrv')
    id = "#{state_abbr} - #{county}"
    data = [row.fetch('Median Home Price Q3 2022')]
    csv << [id, county, state_abbr] + data
  end
end

CSV.open("#{parsed_data_path}/population.csv", 'w') do |csv|
  csv << ["ID", "Population"]
  CSV.read("#{orig_data_path}/population.csv", headers: true).each do |row|
    county = row.fetch('CTYNAME')
    state = row.fetch('STNAME')
    next if state == county

    state_abbr = STATE_ABBR_BY_STATE.fetch(state)
    id = "#{state_abbr} - #{county}"
    population = row.fetch('POPESTIMATE2020')
    csv << [id, population]
  end
end

CSV.open("#{parsed_data_path}/president.csv", 'w') do |csv|
  csv << ["ID", "candidate", 'votes']
  CSV.read("#{orig_data_path}/president.csv", headers: true).each do |row|
    county = row.fetch('county')
    state = row.fetch('state')
    state_abbr = STATE_ABBR_BY_STATE.fetch(state)
    id = "#{state_abbr} - #{county}"
    csv << [id, row.fetch('candidate'), row.fetch('total_votes')]
  end
end

CSV.open("#{parsed_data_path}/land_area.csv", 'w') do |csv|
  csv << ["ID", "land area in square miles"]
  CSV.read("#{orig_data_path}/land_area.csv", headers: true).each do |row|
    area_name = row.fetch('Areaname')
    next unless area_name.include?(',')

    county, state_abbr = area_name.split(',')
    county.strip!
    state_abbr.strip!

    # LND110210D = Land area in square miles 2010
    # according to MASTDATA.xls
    land_area_sq_miles_2010 = BigDecimal(row.fetch('LND110210D'))
    id = "#{state_abbr} - #{county} County"
    csv << [id, land_area_sq_miles_2010.to_f.round(0)]
  end
end
