* NDC data - GET OLD NDC MATCHDS
*link to data
*Created: August 13, 2018
*Last updated: August 14, 2018
		
capture log close
clear all
set more off
set matsize 800
*Maxvar not allowed in my STATA/IC
*Matsize max is 800

*log file

local a "/Users/ramanyakkala/Desktop/OneDrive - California Polytechnic State University/Stata_Summer_Research/State Util"
cd "`a'"

local today2 : di %td_CY-N-D  date("$S_DATE", "DMY") 
local today : di strtrim("`today2'")
di "`today'"

log using testing_NADAC_`today'.log, replace
disp "DateTime: $S_DATE $S_TIME"

import delimited "`a'/NADAC__National_Average_Drug_Acquisition_Cost_.csv", stringcols(2) clear 
generate GENERIC = 0

// G represents that NADAC treated the drug as a Generic in its costing
replace GENERIC = 1 if strmatch(classification, "G")

generate last_effective = date(asof,"MDY")
format last_effective %dM_d,_CY

generate start_effective = date(effec,"MDY")
format start_effective %dM_d,_CY

sort ndc effective nadac

by ndc effective nadac: egen max_date = max(last_effective)

format max_date %dM_d,_CY

sort ndc start_effective last_effective

keep if max_date == last_effective

drop max_date

gen quarter1 = 0
gen quarter2 = 0

gen year = year(start)
gen month = month(start)

forval t = 2013/2018 {
	replace quarter1 = 1 if inrange(start_effective, mdy(1,1,`t'), mdy(3,31,`t')) 
	replace quarter1 = 2 if inrange(start_effective, mdy(4,1,`t'), mdy(6,31,`t'))
	replace quarter1 = 3 if inrange(start_effective, mdy(7,1,`t'), mdy(9,31,`t'))
	replace quarter1 = 4 if inrange(start_effective, mdy(10,1,`t'), mdy(12,31,`t'))
	}
	
forval t = 2013/2018 {
	replace quarter2 = 1 if inrange(last_effective, mdy(1,1,`t'), mdy(3,31,`t')) 
	replace quarter2 = 2 if inrange(last_effective, mdy(4,1,`t'), mdy(6,31,`t'))
	replace quarter2 = 3 if inrange(last_effective, mdy(7,1,`t'), mdy(9,31,`t'))
	replace quarter2 = 4 if inrange(last_effective, mdy(10,1,`t'), mdy(12,31,`t'))
	}

gen quarter_start = yq(year,quarter1)
gen quarter_end = yq(year,quarter2)

*gen test = ""
*forval t=2006/2017{
*	replace test = "`t'-01" if year == `t' & quarter == 1
*	replace test = "`t'-04" if year == `t' & quarter == 2
*	replace test = "`t'-07" if year == `t' & quarter == 3
*	replace test = "`t'-10" if year == `t' & quarter == 4
*	}
	
save "`c'/nadac.dta", replace
