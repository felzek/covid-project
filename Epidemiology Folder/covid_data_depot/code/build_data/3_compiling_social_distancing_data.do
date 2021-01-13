**** This code is a demonstration for compiling the SafeGraph Social-distancing
**** Metrics data for estimation.
**** SafeGraph distributes data freely to COVID-19 researchers after they sign up 
**** at https://www.safegraph.com/covid-19-data-consortium
**** The code is written in Stata 16

* March 2020 data
*** load the raw data of March 1
insheet using "./myLocalDirectory/2020/03/01/2020-03-01-social-distancing.csv", comma clear

* extract geo fips code
gen state = floor(origin_census_block_group / (1e+10))
gen county_temp = origin_census_block_group - state * (1e+10)
gen county = floor(county_temp / (1e+7))
gen tract_temp = origin_census_block_group - state * (1e+10) - ///
		county * (1e+7)
gen tract = floor(tract_temp / 10)
drop county_temp tract_temp
save ./StataResults/temp3, replace

* continue appending the remaining days of the month
forval j = 9/31{

	local date : di %02.0f `j'  
	*skip 8 days due to Incubation period of COVID-19
	display `j'
	insheet using "./myLocalDirectory/2020/03/`date'/2020-03-`date'-social-distancing.csv", 	comma clear

	gen state = floor(origin_census_block_group / (1e+10))
	gen county_temp = origin_census_block_group - state * (1e+10)
	gen county = floor(county_temp / (1e+7))
	gen tract_temp = origin_census_block_group - state * (1e+10) - ///
		county * (1e+7)
	gen tract = floor(tract_temp / 10)
	drop county_temp tract_temp

	append using ./StataResults/temp3
	save ./StataResults/temp3, replace
}

use ./StataResults/temp3, clear
* define date
gen date_str = substr(date_range_start, 1, 10)
gen date = date(date_str, "YMD")

save ./StataResults/tract_group_social_distancing_032020, replace


**** define measures
gen home_ratio = completely_home_device_count / device_count 
gen work_ft_ratio = full_time_work_behavior_devices / device_count
gen work_pt_ratio = part_time_work_behavior_devices / device_count
gen work_ratio = (full_time_work_behavior_devices + part_time_work_behavior_devices)/device_count

rename median_home_dwell_time home_dwell_time
rename distance_traveled_from_home distance_traveled

**** aggregate up to county level
collapse (median) home_ratio work_ft_ratio work_pt_ratio work_ratio home_dwell_time distance_traveled [aweight=device_count], by(state county date)
gen year1 = year(date)
gen month1 = month(date)
gen day1 = day(date) 
save ./StataResults/county_social_distancing_jun16_jun21, replace