clear all
set more off

*ssc install outreg2
*ssc install ivreg2, replace
*ssc install xtivreg2, replace
*ssc install ranktest, replace
*ssc install asdoc,replace

** Note, before running this code, all processed or raw data have been 
** converted into Stata format. Many free software packages can do such conversions. 
** For example, in R, using the package "foreign", a csv file can be converted into 
** a Stata file. Reference: https://www.statmethods.net/input/exportingdata.html

*cd "$data"

* county social distancing
use ./StataResults/county_social_distancing_jun16_jun21, clear

*Use PCA first component as social distancing	
pca home_ratio work_ft_ratio work_pt_ratio home_dwell_time distance_traveled
predict pc1, score
gen social_distancing = -pc1

gen month = month(date)
gen day = day(date)

gen fips = state*1000+county

unique fips

*merge with case data
merge 1:1 fips date using ./StataResults/county_cases.dta
*06-19 we assign the cases of 5 NYC boroughs to their respective counties, yet they only start on the Feb 29 when Manhattan had the first case. Need to fill in 0's for all dates before that
foreach x of numlist 36061 36047 36081 36005 36085{
	replace cum_case = 0 if cum_case == . & fips == `x'
	replace cum_death = 0 if cum_death == . & fips == `x'
	replace _m = 3 if _m == 1 & fips == `x'
}


keep if _merge == 3
drop _merge

unique fips

*merge with county attributes
merge m:1 state county using ./StataResults/county_attributes.dta
keep if _merge == 3
drop _merge
unique fips


*merge with rain and temperature
merge 1:1 fips date using ./covid_data_depot/raw_data/temp_and_rain.dta
tab _m, m
drop if _merge == 2
drop _merge

unique fips


*merge with humidity
merge 1:1 fips date using ./covid_data_depot/raw_data/humidity.dta
drop if _merge == 2
drop _merge

*for a few counties without weather data on certain days, use state averages instead

foreach x of varlist rain avg_temp humidity{
	egen state_`x'=mean(`x'), by(state date)
	replace `x' = state_`x' if `x' == .
}

unique fips


*capture cd "$data"
save ./StataResults/pre_regressions_newdata, replace

***************************************************
gen multiplier = 10

xtset fips date

*new cases
gen new_report = cum_case - l1.cum_case
gen new_case = new_report

*correct for the negative reported new cases
egen min_new_case=min(new_case)
local min = min_new_case
count if new_case<0

foreach i of numlist 1/50{
	display `i' "   "  "min of new_case" "	" min
if min < 0 {
	replace new_case = new_case + f1.new_case if f1.new_case <0
	replace new_case = 0 if new_report < 0
	cap drop min_new_case
	egen min_new_case=min(new_case)
	local min = min_new_case
	count if new_case<0
	replace new_report = new_case
	}
}


unique fips

	replace new_case = multiplier*new_case

	*USE LEAD 5!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	gen new_case_2 = f5.new_case
	drop if new_case_2 == . 
	
	*correct for cumulative cases
	bysort fips (date) : gen cum_case_2 = sum(new_case_2)
	
	unique fips
	
	gen S = 1 - l1.cum_case_2/pop 
	gen log_S = log(S)
	
	gen log_case = log(new_case_2+1) - log_S
	drop if log_case == .
	
	unique fips
	
	gen logY=.
	sort fips date 
	by fips: gen ylag2 = cum_case_2[_n-2]
	sort fips date 
	by fips: gen ylag8 = cum_case_2[_n-8]
	
	*05/29 replace missing values of ylag2 and ylag8 to be 0's
	replace ylag2 = 0 if ylag2 == .
	replace ylag8 = 0 if ylag8 == .
	
	replace logY = log(ylag2 - ylag8 )
	*count if logY == . &ylag2>0 & ylag2!=. & ylag8>0 & ylag8!=.
	drop if logY == .

	unique fips

	
	*05/29 Fips 47169 has strange jump in cases between April 30 and May 1st. Remove it from the sample
	drop if fips == 47169
	
	
	*remove obs when lex == 10^(-7)
	*"If we want a uniform cutoff, I think we can cut off any LEX measure < 10^-7. That would be equivalent to 1 case in the most-populous county, LA county (which has almost 10M people)" --- Raph
	*drop if lex < 10^(-7)
	*gen log_lex = log(lex)
	
	unique fips

	*weather data
	replace rain = rain/10
	replace avg_temp = avg_temp/10
	drop if rain == .
	drop if humidity == .
	
	unique fips


	
	
	
	* cd "$data"
	save ./StataResults/final_covid_data, replace
