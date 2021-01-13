*global data "~/Dropbox/Research/covid_data_depot/raw_data"
*global repo	"~/Dropbox/Research/covid_data_depot/processed_data"
********** build tract level demographic dataset
* change to raw data directory
* capture cd "$data"
import delimited using ./covid_data_depot/raw_data/median_income_tract_2018.csv, clear varnames(1)
* change to processed data directory
* capture cd "$repo"

keep gisjoin ajzae001
rename ajzae001 median_income

save ./StataResults/tract_income, replace

* change to raw data directory
*capture cd "$data"
import delimited using ./covid_data_depot/raw_data/gender_race_age_tract_2018.csv, clear varnames(1)
* change to processed data directory
*capture cd "$repo"

keep gisjoin state* county* tracta name_e ajwbe* ajwne* ajwve*


rename ajwbe001 pop_total
rename ajwbe002 pop_male
rename ajwbe026 pop_female


rename ajwbe003 pop_male_0_5
rename ajwbe004 pop_male_5_9
rename ajwbe005 pop_male_10_14
rename ajwbe006 pop_male_15_17
rename ajwbe007 pop_male_18_19
rename ajwbe008 pop_male_20
rename ajwbe009 pop_male_21
rename ajwbe010 pop_male_22_24
rename ajwbe011 pop_male_25_29
rename ajwbe012 pop_male_30_34
rename ajwbe013 pop_male_35_39
rename ajwbe014 pop_male_40_44
rename ajwbe015 pop_male_45_49
rename ajwbe016 pop_male_50_54
rename ajwbe017 pop_male_55_59
rename ajwbe018 pop_male_60_61
rename ajwbe019 pop_male_62_64
rename ajwbe020 pop_male_65_66
rename ajwbe021 pop_male_67_69
rename ajwbe022 pop_male_70_74
rename ajwbe023 pop_male_75_79
rename ajwbe024 pop_male_80_84
rename ajwbe025 pop_male_85


rename ajwbe027 pop_female_0_5
rename ajwbe028 pop_female_5_9
rename ajwbe029 pop_female_10_14
rename ajwbe030 pop_female_15_17
rename ajwbe031 pop_female_18_19
rename ajwbe032 pop_female_20
rename ajwbe033 pop_female_21
rename ajwbe034 pop_female_22_24
rename ajwbe035 pop_female_25_29
rename ajwbe036 pop_female_30_34
rename ajwbe037 pop_female_35_39
rename ajwbe038 pop_female_40_44
rename ajwbe039 pop_female_45_49
rename ajwbe040 pop_female_50_54
rename ajwbe041 pop_female_55_59
rename ajwbe042 pop_female_60_61
rename ajwbe043 pop_female_62_64
rename ajwbe044 pop_female_65_66
rename ajwbe045 pop_female_67_69
rename ajwbe046 pop_female_70_74
rename ajwbe047 pop_female_75_79
rename ajwbe048 pop_female_80_84
rename ajwbe049 pop_female_85


rename ajwne002 pop_white
rename ajwne003 pop_black
rename ajwne005 pop_asian
rename ajwve012 pop_hispanic // note: hispanic is not mutually exclusive from other races

drop name_e state county aj*
rename statea state
rename countya county
rename tracta tract

merge 1:1 gisjoin using ./StataResults/tract_income, nogen
drop gisjoin

save ./StataResults/tract_demo, replace


* aggregate to county level
use ./StataResults/tract_demo, clear
collapse (sum) pop*, by(state county)

gen frac_male = pop_male / pop_total

foreach vari in male_0_5 male_5_9 male_10_14 male_15_17 /// 
	male_18_19 male_20 male_21 male_22_24 male_25_29 /// 
	male_30_34 male_35_39 male_40_44 male_45_49 ///
	male_50_54 male_55_59 male_60_61 male_62_64 ///
	male_65_66 male_67_69 male_70_74 male_75_79 ///
	male_80_84 male_85{
		gen frac_`vari' = pop_`vari' / pop_total
	}

foreach vari in female_0_5 female_5_9 female_10_14 female_15_17 /// 
	female_18_19 female_20 female_21 female_22_24 female_25_29 /// 
	female_30_34 female_35_39 female_40_44 female_45_49 ///
	female_50_54 female_55_59 female_60_61 female_62_64 ///
	female_65_66 female_67_69 female_70_74 female_75_79 ///
	female_80_84 female_85{
		gen frac_`vari' = pop_`vari' / pop_total
	}

foreach vari in white black asian hispanic{
	gen frac_`vari' = pop_`vari' / pop_total
	// note: hispanic is not mutually exclusive from other races
}
drop pop*
save ./StataResults/temp, replace

use ./StataResults/tract_demo, clear
collapse (median) median_income [aweight=pop_total], by(state county)
merge 1:1 state county using ./StataResults/temp, nogen
outsheet using ./StataResults/county_demo.csv, comma replace
