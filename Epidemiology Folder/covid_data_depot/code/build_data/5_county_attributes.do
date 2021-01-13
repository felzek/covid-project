*global data "~/Dropbox/Research/covid_data_depot/raw_data"
*global repo	"~/Dropbox/Research/covid_data_depot/processed_data"

* county level population data and density. 
* Note this is based on an estimate of the population of 2019. 

* change to data directory
*capture cd "$data"
insheet using "./covid_data_depot/raw_data/co-est2019-alldata.csv", comma clear

* change to git directory
*capture cd "$repo"

rename popestimate2019 pop /* use population 2018 as the area is from 2019*/
drop if county==0 /*this is the US as a whole*/

keep region division state county stname ctyname pop
gen fips = state*1000 + county
save ./StataResults/county_attributes, replace

******* land area data to compute population density
* change to data directory
*capture cd "$data"
insheet using "./covid_data_depot/raw_data/cbg_geographic_data.csv", comma clear

* change to git directory
*capture cd "$repo"

* keep relevant variables
keep census_block_group amount_land
rename amount_land land_area
* convert from squared meters to squred miles
replace land_area = land_area / (2.59e+6)

gen state = floor(census_block_group / (1e+10))
gen county_temp = census_block_group - state * (1e+10)
gen county = floor(county_temp / (1e+7))
drop county_temp

collapse (sum) land_area, by(state county)
merge 1:1 state county using ./StataResults/county_attributes, keep(3) nogen
gen pop_density = pop / land_area
drop land_area
save ./StataResults/county_attributes, replace


******* transportation mode in percentage
* change to data directory
*capture cd "$data"
import delimited "./covid_data_depot/raw_data/Cleaned County Commuter Patterns 5 years 2018.csv", varnames(2) clear
* change to git directory
*capture cd "$repo"

gen fips = substr(id, 10, 5)
destring fips, replace
drop if totalworkers == "null"
* keep fips fraction*
destring totalworkers-fractioncab, replace
rename cartruckorvantowork car_allworkers
rename publictransportationexcludingtax public_transit_allworkers
rename walkedtowork walk_allworkers 
rename bicycletowork bike_allworkers
rename taxicabmotorcycleorothermeanstow cab_allworkers
renvars fractioncar-fractioncab, presub(fraction)
renvars car-cab, postfix(_commuter)
drop id geo margin
* one county (new mexico) does not have data
merge 1:1 fips using ./StataResults/county_attributes, keep(2 3) nogen

save ./StataResults/county_attributes, replace

********** county level demographics
********** we have data at tract level. 
//I have aggregated it up to county level with tract population as weights.
use ./StataResults/county_demo, clear
merge 1:1 state county using ./StataResults/county_attributes, keep(2 3) nogen
outsheet using ./StataResults/county_attributes.csv, comma replace
