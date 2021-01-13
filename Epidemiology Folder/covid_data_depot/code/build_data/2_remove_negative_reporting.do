/*
There are a few days where there are negative cases that are reported. These are generally corrections to previous over-reporting. Thus, we clean the negative numbers of cases by subtracting the absolute value of the negative cases from the proceeding day. In the event that that leads to a negative number of the proceeding day, we iterate again.
*/

use ./StataResults/county_cases, clear

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

drop new_report min_new_case

save ./StataResults/county_cases_negative_removed, replace
