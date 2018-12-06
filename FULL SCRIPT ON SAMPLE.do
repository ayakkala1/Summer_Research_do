*Before you begin make or check for a folder for Sample files. That will go into local b

*NDC data - FULL SCRIPT ON SAMPLE STATEUTIL
*link to data
*Created: July 26, 2018
*Last updated: July 26, 2018
		
capture log close
clear all
set more off
set matsize 800
*Maxvar not allowed in my STATA/IC
*Matsize max is 800

*log file
local a "/Users/ramanyakkala/Desktop/OneDrive - California Polytechnic State University/Stata_Summer_Research/State Util"
local b "/Users/ramanyakkala/Desktop/OneDrive - California Polytechnic State University/Stata_Summer_Research/State Util/Sample"
local c "/Users/ramanyakkala/Desktop/OneDrive - California Polytechnic State University/Stata_Summer_Research/Natality"

cd "`a'"

local today2 : di %td_CY-N-D  date("$S_DATE", "DMY") 
local today : di strtrim("`today2'")
di "`today'"

log using STATEUTIL_ANDA_sample_`today'.log, replace
disp "DateTime: $S_DATE $S_TIME"

clear
*! version 1.1.0, 07sep2014, Robert Picard, picard@netbox.com      
program randomtag

	version 9
	
	syntax [if] [in] , ///
	Count(integer) ///
	[ ///
	Generate(name) ///
	]
	
	if "`generate'" == "" local generate _randomtag
	confirm new variable `generate'
	
	if _N == 0 error 2000
	
	if `count' <= 0 error 411
	
	if `"`if'`in'"' != "" {
		marksample touse
		mata: tag_it_touse("`generate'",`count', "`touse'")
	}
	else mata: tag_it("`generate'",`count')
		
end


version 9.2
mata:
mata set matastrict on


void tag_it_touse(

	string scalar tagvar,		// name of new variable to generate
	real scalar count, 			// number of draws
	string scalar touse			// varname of sample indicator variable
	
	)
{

	real colvector	///
		insample,	///	touse sample indicator
		iobs,		/// indices of observations in the touse sample
		u1, 		/// primary uniformly distributed random variates
		pick,		/// indicator for picked observations
		isub,		/// indices of obs in subset used to make final picks
		u1sub,		/// subset of u1 used to make final picks
		u2sub,		/// secondary random variates to break ties in u1sub
		ix,			/// indices/x matrix that is sorted for final picks
		ipick		/// indices of final picks.

	real scalar		///
		nobs, 		///	number of observations
		cutoff,		///	a value such that sum(u1 :< cutoff)  ~== count
		highcut,	/// a value such that sum(u1 :< highcut) > count
		lowcut,		/// a value such that sum(u1 :< lowcut)  < count
		nlow,		/// equal to sum(x :< lowcut)
		n			/// stores sum(x :< cutoff) while iterating


	// select obs included in the sample
	insample = st_data(.,touse)
	iobs = select(range(1,st_nobs(),1),insample)
	nobs = length(iobs)
	if (nobs == 0) exit(error(2000))
	
	// roll back the number of draws if > number of observations
	count = (nobs < count ? nobs : count)
	
	// primary uniformly distributed random variate on [0,1)
	u1 = uniform(nobs, 1)
	
	// initial estimate of cutoff needed for sum(u1 :< cutoff) == count
	cutoff = count / nobs

	// refine cutoff by finding high and low cutoff values
	n = sum(u1 :< cutoff)
	if (n > count) {
		highcut = cutoff
		while (n > count) {
			cutoff = cutoff - 1.05 * (n - count) / nobs
			n = sum(u1 :< cutoff)
		}
		lowcut = cutoff
		nlow = n
	}
	else if (n < count) {
		lowcut = cutoff
		nlow = n
		while (n < count) {
			cutoff = cutoff + 1.05 * (count - n) / nobs
			n = sum(u1 :< cutoff)
		}
		highcut = cutoff
	}
	
	pick = J(st_nobs(),1,0)
	
	if (n != count) {
	
		// pick obs with u1 below lowcut
		ipick = select(range(1,nobs,1), u1 :< lowcut)
		pick[iobs[ipick]] = J(length(ipick),1,1)

		// select a subset with u1 in the range of [lowcut,highcut]
		isub = select(range(1,nobs,1), u1 :>= lowcut :& u1 :<= highcut)
		
		// sort u1 within the subset; because uniform() draws random
		// numbers with replacement (see http://blog.stata.com/tag/random-numbers/),
		// duplicates may arise. Use an secondary vector of random numbers
		// to break such ties. Finally, adding the indices makes the
		// sort fully replicable no matter what
		u1sub =  u1[isub]
		u2sub = uniform(length(isub), 1)
		ix = sort((isub, u1sub, u2sub), (2,3,1))
		
		// pick remaining obs to reach the requested count
		ipick = ix[|1,1 \ count-nlow,1|]
		pick[iobs[ipick]] = J(length(ipick),1,1)
		
		st_store(., st_addvar("byte", tagvar),  pick)
		
	}
	else {
	
		// the cutoff selects exactly count observations
		pick[iobs[select(range(1,nobs,1), u1 :< cutoff)]] = J(count,1,1)
		st_store(., st_addvar("byte", tagvar), pick)
		
	}

}


void tag_it(

	string scalar tagvar,		// name of new variable to generate
	real scalar count 			// number of draws
	
	)
{

	real colvector	///
		u1, 		/// primary uniformly distributed random variates
		pick,		/// indicator for picked observations
		isub,		/// indices of obs in subset used to make final picks
		u1sub,		/// subset of u1 used to make final picks
		u2sub,		/// secondary random variates to break ties in u1sub
		ix,			/// indices/x matrix that is sorted for final picks
		ipick		/// indices of final picks.
		
	real scalar		///
		nobs, 		///	number of observations
		cutoff,		///	a value such that sum(u1 :< cutoff)  ~== count
		highcut,	/// a value such that sum(u1 :< highcut) > count
		lowcut,		/// a value such that sum(u1 :< lowcut)  < count
		nlow,		/// equal to sum(x :< lowcut)
		n			/// stores sum(x :< cutoff) while iterating
		

	// roll back the number of draws if > number of observations
	nobs = st_nobs()
	count = (nobs < count ? nobs : count)
	
	// primary uniformly distributed random variate on [0,1)
	u1 = uniform(nobs, 1)
	
	// initial estimate of cutoff needed for sum(u1 :< cutoff) == count
	cutoff = count / nobs

	// refine cutoff by finding high and low cutoff values
	n = sum(u1 :< cutoff)
	if (n > count) {
		highcut = cutoff
		while (n > count) {
			cutoff = cutoff - 1.05 * (n - count) / nobs
			n = sum(u1 :< cutoff)
		}
		lowcut = cutoff
		nlow = n
	}
	else if (n < count) {
		lowcut = cutoff
		nlow = n
		while (n < count) {
			cutoff = cutoff + 1.05 * (count - n) / nobs
			n = sum(u1 :< cutoff)
		}
		highcut = cutoff
	}
	
	if (n != count) {

		// pick obs with u1 below lowcut
		pick = u1 :< lowcut
		
		// select a subset with u1 in the range of [lowcut,highcut]
		isub = select(range(1,nobs,1), u1 :>= lowcut :& u1 :<= highcut)
		
		// sort u1 within the subset; because uniform() draws random
		// numbers with replacement (see http://blog.stata.com/tag/random-numbers/),
		// duplicates may arise. Use an secondary vector of random numbers
		// to break such ties. Finally, adding the indices makes the
		// sort fully replicable no matter what
		u1sub =  u1[isub]
		u2sub = uniform(length(isub), 1)
		ix = sort((isub, u1sub, u2sub), (2,3,1))
		
		// pick remaining obs to reach the requested count
		ipick = ix[|1,1 \ count-nlow,1|]
		pick[ipick] = J(length(ipick),1,1)
		st_store(., st_addvar("byte", tagvar), pick)
				
	}
	else st_store(., st_addvar("byte", tagvar), u1 :< cutoff)

}

end
use "`a'/2006.dta"
// start with 2006.dta in your STATA

forval t=2007/2017 {
	append using "`a'/`t'.dta"
	
	}
	
gen newndc = substr("0000000", 1, 11 - length(ndc)) + ndc
drop if strmatch(state,"XX")

*random sample - use to trouble-shoot code
gen unique = state + ndc
local stosample 4000

     *tag one obs of store-brand groups (NDC-state)
         egen stotag = tag(unique)

     *select a random sample from the tagged obs
         set seed 783489
         randomtag if stotag, count(`stosample') gen(t)

     *keep all obs from picked store-brand groups
         bysort unique: egen select=total(t)

         keep if select
save "`b'/aggregate_stateutil_sample.dta",replace

* THIS IMPORTS THE PRODUCT AND PACKAGE DATA

clear
import delimited "`a'/product.txt
save "`b'/product_sample.dta", replace

clear
import delimited "`a'/package.txt
save "`b'/package_sample.dta", replace

* THIS MAKES MARKS OBS THAT ARE GENERIC THROUGH ANDA APPROVAL OR AUTHORIZED GENERICS

use "`b'/product_sample.dta"

gen GENERIC = 0
replace GENERIC = 1 if strpos(marketingcategoryname,"ANDA")>0

drop if strmatch(productid,"")

gen OTC=0
replace OTC = 1 if strpos(producttypename,"OTC")>0

save "`b'/Generic_product_sample.dta",replace

*THIS IS SETTING THE PRODUCT DATA BY CONVERTING 10 DIGIT NDC TO 11 DIGIT

use "`b'/package_sample.dta"

split ndcpackagecode, parse("-") generate(splitndc)
gen splitndc1_new = substr("000000", 1, 5 - length(splitndc1)) + splitndc1
gen splitndc2_new = substr("000000", 1, 4 - length(splitndc2)) + splitndc2
gen splitndc3_new = substr("000000", 1, 2- length(splitndc3)) + splitndc3

forval t = 1/3{
drop splitndc`t'
}

gen newndc = splitndc1_new+splitndc2_new+splitndc3_new

forval t = 1/3{
drop splitndc`t'_new
}

drop ndcpackagecode

save "`b'/new_ndc_package_sample.dta",replace

*IMPORT AND CLEAN NDC SPL DATA

clear
import delimited "`a'/Comprehensive NDC SPL Data Elements File.csv"
save "`b'/NDC_SPL_raw_sample.dta",replace

clear
import delimited "`a'/firms.csv"
tostring lblcode,replace
save "`b'/firms_raw_sample.dta",replace

use "`b'/NDC_SPL_raw_sample.dta"
merge m:1 lblcode using "`a'/firms_raw.dta"
drop if strmatch(firm_name,"")
save "`b'/NDC_SPL_firms_raw_sample.dta",replace

rename _merge merge1

gen GENERIC = 0
replace GENERIC = 1 if strpos(marketingcategory,"ANDA")>0

gen OTC = 0
replace OTC = 1 if strpos(marketingcategory,"OTC")>0

gen newndc = substr("000000000",1,11-length(ndc11))+ndc11
duplicates drop newndc GENERIC, force

save "`b'/Generic_NDC_SPL_firms_sample.dta",replace

*MERGE PRODUCT AND PACKAGE AND MERGE THAT WITH STATE UTIL

clear
use "`b'/new_ndc_package_sample.dta"

merge m:1 productid using "`b'/Generic_product_sample.dta", keepusing(GENERIC)
drop if strmatch(newndc,"")
rename _merge merge1
merge m:1 productid using "`b'/Generic_product_sample.dta", keepusing(OTC)
drop if strmatch(newndc,"")
duplicates drop newndc,force
save "`b'/merge_package_product_sample.dta",replace

clear
use "`b'/aggregate_stateutil_sample.dta"
merge m:1 newndc using "`b'/merge_package_product_sample.dta",keepusing(GENERIC)
rename _merge merge1
merge m:1 newndc using "`b'/merge_package_product_sample.dta",keepusing(OTC)
rename _merge merge2
save "`b'/generic_aggregate_stateutil_sample.dta",replace

*MERGE SPL DATA WITH STATE UTIL

clear

use "`b'/generic_aggregate_stateutil_sample.dta"
merge m:1 newndc using "`b'/Generic_NDC_SPL_firms_sample.dta", keepusing(GENERIC) update
rename _merge merge3
merge m:1 newndc using "`b'/Generic_NDC_SPL_firms_sample.dta", keepusing(OTC) update
drop if strmatch(ndc,"")
rename _merge merge4
drop if strmatch(state,"XX")
replace GENERIC = 1 if merge3 == 5
replace OTC = 1 if merge4 == 5
*UPDATING OLD'0's TO NEW 1's
save "`b'/finished_aggregate_sample", replace

use "`a'/Applications.txt.dta"
rename applno appl_no
tostring appl_no,replace
replace appl_no=substr("00000000",1,6-length(appl_no))+appl_no
	* The substr is so I can make all codes the same length as a code should be
save "`b'/Applications_new_sample.dta",replace


	* Making a Generic Dummy based on if they applied through ANDA (GENERIC)
use "`a'/applicat.dta"
merge m:1 appl_no using "`b'/Applications_new_sample.dta"
gen GENERIC = 0
replace GENERIC = 1 if strmatch(appltype,"ANDA")
rename _merge merge1
save "`b'/applicat_new_sample.dta", replace


	* I merge the application to the Listing dta which will allow me to start crafting the NDC codes to merge
use "`a'/listings.dta"
merge 1:m listing_seq_no using "`b'/applicat_new_sample.dta"
save "`b'/listings_merge_sample.dta", replace


	* Dropping irrelevant columns so I can have mat space
keep listing_seq_no lblcode prodcode tradename appl_no appltype sponsorname GENERIC
duplicates drop listing_seq_no prodcode,force
save "`b'/listings_merge_unique_sample.dta", replace

use "`a'/packages_old.dta"
merge m:1 listing_seq_no using "`b'/listings_merge_unique_sample.dta"
save "`b'/packages_old_merge_sample.dta",replace

	* Process of me connecting the three seperate variables that make up the NDC variable
clear
use "`b'/packages_old_merge_sample.dta"
gen prodcode_new = ""

	* The code had *'s which I ASSUMED were place-holders for 0's (makes most sense) and replaced them with 0's
replace prodcode_new = substr(prodcode,2,.) if strpos(prodcode,"*")>0
replace prodcode_new = substr(prodcode,1,.) if strpos(prodcode,"*")==0
replace prodcode_new = substr("00000000",1,4-length(prodcode_new))+prodcode_new
drop prodcode
gen newndc = lblcode+prodcode_new+pkgcode
replace newndc = substr(newndc,2,.)
replace newndc = subinstr(newndc, "*", "0",.) 
duplicates drop newndc,force
save "`b'/packages_old_merge_ndc_sample.dta",replace

import delimited "`a'/Drug_Products_in_the_Medicaid_Drug_Rebate_Program.csv", stringcols(4) clear 
gen GENERIC = 0
replace GENERIC = 1 if codstatus == "01"
*COD STATUS 01 MEANS ANDA
duplicates drop ndc GENERIC, force
duplicates tag ndc, gen (tag)
drop if tag == 1
*THERE ARE DUPLICATE NDC WITH DIFFERING CODSTATUS; DON'T KNOW HOW TO DEAL WITH THIS
rename ndc newndc
save "`b'/rebate_more_ndc_sample.dta",replace

use "`b'/finished_aggregate_sample.dta"
merge m:1 newndc using "`b'/packages_old_merge_ndc_sample.dta", keepusing(GENERIC) update
rename _merge merge5
count if GENERIC == .
merge m:1 newndc using "`b'/rebate_more_ndc_sample.dta", keepusing(GENERIC) update
rename _merge merge6
replace GENERIC = 1 if merge3 == 5
replace OTC = 1 if merge4 == 5
replace GENERIC = 1 if merge5 == 5
replace GENERIC = 1 if merge6 == 5
save "`b'/finished_aggregate_more_sample.dta", replace

use "`b'/finished_aggregate_more_sample.dta"
drop if year == 2006
drop if utilizationtype == "MCOU"
split quarterbegin, parse("/") 
destring quarterbegin1, replace
gen yearmo = ym(year,quarterbegin1)
format yearmo %tmnn/CCYY
drop quarterbegin1 quarterbegin2
save "`b'/finished_aggregate_treatment_sample.dta",replace


import excel "/`c'/Import Dates.xlsx", sheet("Sheet1") firstrow clear
save "`b'/DatesPolicy_sample.dta",replace
keep if MML == 1
drop if strmatch(NameofMeasure,"Arizona Use or Possession of Controlled Substances, Proposition 200")
*This was a pass of MML however it didn't actually protect MM users and isn't noted as the policy that legalized MM in Arizon

gen a = year(Implementation)
gen b = month(Implementation)
gen yearmo = ym(a,b)
format yearmo %tmnn/CCYY
drop a b

foreach x of var* {
	rename `x' `x'_MML
	}

*Above is where I create the post_MML
	
rename State_MML state
save "`b'/DatesPolicyMML_sample.dta",replace

use "`b'/DatesPolicy_sample.dta"
keep if LEGALIZATION == 1

gen a = year(Implementation)
gen b = month(Implementation)
gen yearmo = ym(a,b)
format yearmo %tmnn/CCYY
drop a b


foreach x of var* {
	rename `x' `x'_REC
	}

rename State_REC state
save "`b'/DatesPolicyRec_sample.dta",replace

use "`b'/finished_aggregate_treatment_sample.dta"
merge m:1 state using "`b'/DatesPolicyMML_sample.dta", keepusing(yearmo_MML) nogenerate
merge m:1 state using "`b'/DatesPolicyRec_sample.dta", keepusing(yearmo_REC)nogenerate
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
gen tests = ndc+state
egen newid = group(tests)
xtset newid yearmo
replace unitsreimbursed = unitsreimbursed + 1
gen logunits = ln(unitsreimbursed)

preserve

replace GENERIC = 1 if GENERIC == .
xtreg logunits i.year i.postMML#GENERIC i.postREC#GENERIC,vce(cl state) fe
outreg2 using "`a'/Regressions_Generic.xls",replace ctitle(GENERIC_ANALYSIS_1)

restore

replace GENERIC = 0 if GENERIC == .
xtreg logunits i.year i.postMML#GENERIC i.postREC#GENERIC,vce(cl state) fe
outreg2 using "`a'/Regressions_Generic.xls",append ctitle(GENERIC_ANALYSIS_0)

restore

save "`a'/finished_aggregate_treatment_analysis_sample.dta", replace


