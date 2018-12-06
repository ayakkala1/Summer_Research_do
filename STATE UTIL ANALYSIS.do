*NDC data - STATEUTIL ( NO RECOG ANDA ) ANALYSIS
*link to data
*Created: July 25, 2018
*Last updated: July 25, 2018
		
capture log close
clear all
set more off
set matsize 800
*Maxvar not allowed in my STATA/IC
*Matsize max is 800

*log file

local a "/Users/ramanyakkala/Desktop/OneDrive - California Polytechnic State University/Stata_Summer_Research/State Util"
local b "/Users/ramanyakkala/Desktop/OneDrive - California Polytechnic State University/Stata_Summer_Research/Natality"

cd "`a'"

local today2 : di %td_CY-N-D  date("$S_DATE", "DMY") 
local today : di strtrim("`today2'")
di "`today'"

log using STATEUTIL_ANALYSIS_`today'.log, replace
disp "DateTime: $S_DATE $S_TIME"

use "`a'/finished_aggregate_more.dta"
rename _merge merge6
drop if strmatch(ndc,"")
drop if year == 2006
drop if utilizationtype == "MCOU"
split quarterbegin, parse("/") 
destring quarterbegin1, replace
gen yearmo = ym(year,quarterbegin1)
format yearmo %tmnn/CCYY
drop quarterbegin1 quarterbegin2
save "`a'/finished_aggregate_treatment.dta",replace


import excel "/`b'/Import Dates.xlsx", sheet("Sheet1") firstrow clear
save "`a'/DatesPolicy.dta",replace
keep if MML == 1
drop if strmatch(NameofMeasure,"Arizona Use or Possession of Controlled Substances, Proposition 200")
*This was a pass of MML however it didn't actually protect MM users and isn't noted as the policy that legalized MM in Arizon

gen a = year(Implementation)
gen b = month(Implementation)
gen yearmo = ym(a,b)
format yearmo %tmnn/CCYY
order yearmo, a(Implementation)
drop a b

foreach x of var* {
	rename `x' `x'_MML
	}

*Above is where I create the post_MML
	
rename State_MML state
save "`a'/DatesPolicyMML.dta",replace

use "`b'/DatesPolicy.dta"
keep if LEGALIZATION == 1

gen a = year(Implementation)
gen b = month(Implementation)
gen yearmo = ym(a,b)
format yearmo %tmnn/CCYY
order yearmo, a(Implementation)
drop a b


foreach x of var* {
	rename `x' `x'_REC
	}

rename State_REC state
save "`a'/DatesPolicyRec.dta",replace

use "`a'/finished_aggregate_treatment.dta"
merge m:1 state using "`a'/DatesPolicyMML.dta", keepusing(yearmo_MML) nogenerate
merge m:1 state using "`a'/DatesPolicyRec.dta", keepusing(yearmo_REC) nogenerate
gen yearmo_end = yearmo + 3
format yearmo_end %tmnn/CCYY
gen postMML = 0
* Since quarter's aren't in the same timeframe as our treatment. I am assigning the indicator variable if the treatment
* was in the timeframe of the quarter. The Medicaid data gives example (Jan 1 - March 31st). Since our data doesn't go
* into day precision I rounded that to April 1st.
replace postMML = 1 if yearmo_end>=yearmo_MML
gen postREC= 0
replace postREC = 1 if yearmo_end>=yearmo_REC
drop if labelercode == .
save "`a'/finished_aggregate_treatment_analysis.dta", replace


