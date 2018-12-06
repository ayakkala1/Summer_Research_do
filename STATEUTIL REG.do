gen state_drug = state + ndc
egen statecode = group(state_drug)

// Made timeframe month by year since quarter by year would be hard to later merge with additional info about prices etc.
// The month by year is correctly identified by the State Util description

xtset yearmo statecode

**********************
*    tsfill, full
*         bysort id : carryforward state, replace
*         bysort id: carryforward dbead, replace
*         bysort id: carryforward retailer_code, replace
*         bysort id: carryforward store_zip3, replace

     *Fill in higoogle
*     egen higoos=max(higoo), by(state week)
*     gen higoos_bead=higoos*dbead
***********************	 
	 
keep postMML postREC yearmo statecode GENERIC yearmo_MML yearmo_REC
gen ln_doses = ln(numberofprescriptions + 1)
gen iteration = 0

local variables "ln_doses"
foreach dependent in `variables'{
	if iteration == 0 {
		xtreg `dependent' postMML postREC i.year i.monthcode, vce(cl state) fe
		outreg2 using "`a'/Regressions_Generic.xls",replace ctitle(`dependent') 
		}
	else if iteration > 0 {
		xtreg `dependent' postMML postREC i.year i.monthcode, vce(cl state) fe
		outreg2 using "`a'/Regressions_Generic.xls",append ctitle(`dependent')	
		}
	replace iteration = iteration + 1
	}

foreach dependent in `variables'{
	xtreg `dependent' postMML i.year i.monthcode, vce(cl state) fe
	outreg2 using "`a'/Regressions_Generic.xls",append ctitle(`dependent'_MML)
	}

gen time2MML = yearmo_end - yearmo_MML
gen time2REC = yearmo_end - yearmo_REC
replace time2MML = 999 if time2MML == .
replace time2REC = 999 if time2REC == .
char time2MML[omit] -1
char time2REC[omit] -1

foreach dependent in `variables'{
	xi: xtreg `dependent' i.time2MML, vce(cl state) fe
	outreg2 using "`a'/Regressions_Generic.xls",append ctitle(`dependent'_MML_Eventstudy)
	drop _Itime2MML*
	}

	
foreach dependent in `variables'{
	xi: xtreg `dependent' i.time2MML i.year, vce(cl state) fe
	outreg2 using "`a'/Regressions_Generic.xls",append ctitle(`dependent'_MML_Eventstudy_yeardummy)
	drop _Itime2MML*
	}

foreach dependent in `variables'{
	xi: xtreg `dependent' i.time2MML i.year i.monthcode, vce(cl state) fe
	outreg2 using "`a'/Regressions_Generic.xls",append ctitle(`dependent'_MML_Eventstudy_yearmonthdummy)
	drop _Itime2MML*
	}
	
outreg2 using "`a'/Regressions_Generic.xls", excel sum(log) append keep(postMML postREC)

*levelsof state
*foreach lev in `r(levels)' {
	*foreach dependent in `variables' { 
		*preserve
		*keep if strmatch(state,"`lev'")
		*collapse (mean)`dependent' time2MML time2REC, by(yearmo)
		*replace time2MML = -1 if time2MML == .
		*line `dependent' yearmo if time2MML >= 0, legend(lab(2 "post-MML"))|| line `dependent' yearmo if time2REC >=0, legend(lab(1 "post-REC")) || line `dependent' yearmo if time2MML<0 | time2MML == 99 ,legend(lab(3 "pre-MML"))||
		*graph export "`a'/Graphs/`dependent'_`lev'.png", replace
		*restore
	*}
	*}
	
