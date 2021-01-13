*The estimation is implemented using Stata 16

* Load the data
import delimited "./covid_data.csv", clear

* regression 
xi: xtivreg log_case logY avg_temp humidity i.date (social_distancing= rain), fe vce(cluster fips)

* an alternative approach that takes a much longer time to run.
* the output fixed effects and their se are reported
xi:ivreg2 log_case logY avg_temp humidity i.fips i.date (social_distancing= rain), cluster(fips)
