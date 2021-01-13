cd "C:\Users\Bhanu Garg\Desktop"
**** This code is a demonstration for compiling COVID-19 case data for estimation.
**** Please refer to the following document for info about downloading the raw case data
**** from NY Times and NY City Health Department. 
**** https://github.com/songyao21/covid_data_depot/blob/master/Tech_Appendix.pdf
**** The code is written in Stata 16

***** Raw data compiled by New York Times (NYT)
***** case and death data at county-date level
insheet using "./covid-19-data/us-counties.csv", comma clear

***** Two special cases
***** NYT does not present seperate data for the 5 boroughs for New York City (NYC)
***** Kansas City's data are not reported in its county
replace fips = 99991 if county=="New York City"
replace fips = 99992 if county=="Kansas City"
drop if fips == .
keep fips deaths cases date
fillin fips date
drop _fillin

replace cases = 0 if cases==.
replace deaths = 0 if deaths==.

rename date str_date
gen date = date(str_date, "YMD")
drop str_date

rename cases cum_case
rename deaths cum_death

save ./StataResults/county_cases, replace

***** Raw data from NYC Health Department that report cases separately for each borough
import delimited using "./coronavirus-data/archive/boroughs-case-hosp-death.csv", clear

rename mn_case_count case_36061 //Manhattan
rename bk_case_count case_36047 //Brooklyn
rename bx_case_count case_36005 //Bronx
rename qn_case_count case_36081 //Queens
rename si_case_count case_36085 //Richmond (staten island)

rename mn_death_count death_36061 //Manhattan
rename bk_death_count death_36047 //Brooklyn
rename bx_death_count death_36005 //Bronx
rename qn_death_count death_36081 //Queens
rename si_death_count death_36085 //Richmond (staten island)

rename date_ date
gen date_str = date
drop date
gen date=date(date_str, "MDY")
drop date_str
drop bk bx mn qn si

reshape long case_ death_, i(date) j(fips)
bysort fips (date) : gen cum_case = sum(case_)
bysort fips (date) : gen cum_death = sum(death_)
drop case_ death_

* Use NYC Health Department data to replace the NYC data reported by NYT
append using ./StataResults/county_cases
drop if fips==99991
* Kansas City
replace fips=20209 if fips==99992
collapse (sum) cum_case cum_death, by(fips date)
save ./StataResults/county_cases, replace
