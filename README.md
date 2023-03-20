# About SafeSearch

Find a place that balance population, cost, politics and climate risk.

# About the data

I collected and cleaned four data sets, each with county-level data:

- Climate Risk (https://projects.propublica.org/climate-migration/)
- Median Home Sale prices (https://cdn.nar.realtor/sites/default/files/documents/2022-q3-county-median-prices-and-monthly-mortgage-payment-by-price-12-20-2022.pdf)
- Population (https://www.census.gov/data/datasets/time-series/demo/popest/2020s-counties-total.html#par_textimage_739801612)
- 2020 Presidential election results (https://www.kaggle.com/datasets/unanimad/us-election-2020?resource=download&select=president_county_candidate.csv)
- Land area (https://www.census.gov/library/publications/2011/compendia/usa-counties-2011.html#LND)

The original data is in `data/orig`. When you run `convert.rb` it generates the content in `data/parsed` which is intended to be consumed by `analyze.rb`.

# How to filter

There are four filters configured at the top of `analyze.rb`:

- How much can you afford?
- How much population do you want?
- What's your politcs?
- How many results do you want?

This will help you narrow your choices down.

# How to sort

Sorting is not configurable currently. It assumes you want to find the place least-affected by climate change.
This is done by taking the normalized climate risk score and dividing it by the normalized median home price giving you a "risk per dollar" score.

# How to run

```
ruby ./convert.rb && ruby ./analyze.rb
```
