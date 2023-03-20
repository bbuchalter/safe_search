#!/usr/bin/env ruby
# typed: strict
require 'bundler/setup'
require 'csv'
require 'bigdecimal'
require 'sorbet-runtime'
require 'text-table'
require 'friendly_numbers'

##################################################

# How much can you afford?
affordablity_threshold = 300_000

# How big a county do you want?
pop_range = (50_000..150_000)
pop_density = nil

# What's your politcs?
biden_threshold = BigDecimal("0.50")

# How many results do you want?
results_limit = 5

##################################################

parsed_data_path = 'data/parsed'

class RealEstate < T::Struct
  const :id, String
  const :median_home_price, Integer
  const :normalized_median_home_price, BigDecimal
end
home_prices = CSV.read("#{parsed_data_path}/home_prices.csv", headers: true).map { |row| Integer(row.fetch('Median Price')) }
max_median_home_price = BigDecimal(home_prices.max)
min_median_home_price = BigDecimal(home_prices.min)
real_estate_by_id = CSV.read("#{parsed_data_path}/home_prices.csv", headers: true).each_with_object({}) do |row, memo|
  id = row.fetch('ID')
  median_home_price = Integer(row.fetch('Median Price'))
  normalized_median_home_price = ((median_home_price - min_median_home_price) / (max_median_home_price - min_median_home_price)).to_f
  if normalized_median_home_price > BigDecimal("0")
    normalized_median_home_price *= BigDecimal("100")
  else
    normalized_median_home_price = BigDecimal(".1")
  end
  memo[id] = RealEstate.new(
    id: id,
    median_home_price: median_home_price,
    normalized_median_home_price: normalized_median_home_price
  )
end

class Risk < T::Struct
  const :id, String
  const :heat, Integer
  const :wet_bulb, Integer
  const :farm_crop_yields, Integer
  const :sea_level_rise, Integer
  const :very_large_fires, Integer
  const :economic_damages, Integer
  const :total, Integer
  const :normalized_total, BigDecimal
end
max_risk_total = BigDecimal("60")
min_risk_total = BigDecimal("6")
risk_by_id = CSV.read("#{parsed_data_path}/risk.csv", headers: true).each_with_object({}) do |row, memo|
  id = row.fetch('ID')
  total = Integer(row.fetch('Total Risk Score'))
  normalized_total = ((total - min_risk_total) / (max_risk_total - min_risk_total)).to_f
  if normalized_total > BigDecimal("0")
    normalized_total *= BigDecimal("100")
  else
    normalized_total = BigDecimal(".1")
  end
  memo[id] = Risk.new(
    id: id,
    heat: Integer(row.fetch('Heat')),
    wet_bulb: Integer(row.fetch('Wet Bulb')),
    farm_crop_yields: Integer(row.fetch('Farm Crop Yields')),
    sea_level_rise: Integer(row.fetch('Sea Level Rise')),
    very_large_fires: Integer(row.fetch('Very Large Fires')),
    economic_damages: Integer(row.fetch('Economic Damages')),
    total: total,
    normalized_total: normalized_total
  )
end


class Population < T::Struct
  const :id, String
  const :in_2020, Integer
end
population_by_id = CSV.read("#{parsed_data_path}/population.csv", headers: true).each_with_object({}) do |row, memo|
  id = row.fetch('ID')
  population = row.fetch('Population')
  memo[id] = Population.new(id: id, in_2020: Integer(population))
end

class VotesForPresident < T::Struct
  const :id, String
  const :candidate, String
  const :votes, BigDecimal
end
class Politics < T::Struct
  const :id, String
  const :precent_for_biden_in_2020, BigDecimal
end
votes_by_id = CSV.read("#{parsed_data_path}/president.csv", headers: true).each_with_object(Hash.new { |h,k| h[k] = [] }) do |row, memo|
  id = row.fetch('ID')
  memo[id] << VotesForPresident.new(
    id: id,
    candidate: row.fetch('candidate'),
    votes: BigDecimal(row.fetch('votes'))
  )
end
politics_by_id = votes_by_id.each_with_object({}) do |(id, votes), memo|
  biden_votes = votes.find { |v| v.candidate == 'Joe Biden' }.votes
  total_votes = votes.sum(&:votes)
  next if total_votes == 0

  memo[id] = Politics.new(
    id: id,
    precent_for_biden_in_2020: biden_votes / total_votes
  )
end

land_area_by_id = CSV.read("#{parsed_data_path}/land_area.csv", headers: true).each_with_object({}) do |row, memo|
  id = row.fetch('ID')
  memo[id] = Integer(row.fetch("land area in square miles"))
end


class Location < T::Struct
  const :id, String
  const :risk, Risk
  const :real_estate, RealEstate
  const :pop, Population
  const :politics, Politics
  const :land_area_in_sq_miles, Integer

  def risk_per_dollar
    @risk_per_dollar ||= risk.normalized_total / real_estate.normalized_median_home_price
  end

  def population_density
    @population_density ||= BigDecimal(pop.in_2020 / land_area_in_sq_miles)
  end
end
shared_ids = real_estate_by_id.keys & risk_by_id.keys & population_by_id.keys & politics_by_id.keys & land_area_by_id.keys
puts "Analyzing #{shared_ids.count} counties"
locations = shared_ids.map do |id|
  Location.new(
    id: id,
    risk: risk_by_id.fetch(id),
    real_estate: real_estate_by_id.fetch(id),
    pop: population_by_id.fetch(id),
    politics: politics_by_id.fetch(id),
    land_area_in_sq_miles: land_area_by_id.fetch(id)
  )
end


## FILTERING

affordable_locations = locations.filter { |location| location.real_estate.median_home_price <= affordablity_threshold }
puts "Filter median home price: <= #{affordablity_threshold}"

right_population = locations.filter { |location | pop_range.cover?(location.pop.in_2020) }
puts "Filter population: #{pop_range}"

right_politics = locations.filter { |location| location.politics.precent_for_biden_in_2020 >= biden_threshold }
puts "Filter politcs: Percentage of 2020 votes for biden >= #{biden_threshold.to_f.round(2)}"

filtered_locations = right_population & affordable_locations & right_politics

risk_per_dollar_locations = filtered_locations.sort_by(&:risk_per_dollar).first(results_limit)
puts "Returning #{risk_per_dollar_locations.count} results"

risk_per_dollar_table = Text::Table.new
risk_per_dollar_table.head = ['Location', 'Risk per dollar', 'Normalized risk', 'Normalized median home price', 'Median price', 'Population', 'Pop. Density', '% Biden']
risk_per_dollar_locations.each do |location|
  risk_per_dollar_table.rows << [
    location.id,
    location.risk_per_dollar.to_f.round(2),
    location.risk.normalized_total.to_f.round(2),
    location.real_estate.normalized_median_home_price.to_f.round(2),
    FriendlyNumbers.number_to_currency(location.real_estate.median_home_price, precision: 0),
    location.pop.in_2020,
    location.population_density.to_f.round(2),
    location.politics.precent_for_biden_in_2020.to_f.round(2)
  ]
end
puts risk_per_dollar_table.to_s
