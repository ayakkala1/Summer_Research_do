*NDC data - USING DRUGS@FDA DATA AND OLD NDC DATA GET MORE MATCHES
*link to data
*Created: July 17, 2018
*Last updated: July 17, 2018
		
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

log using More_NDC_`today'.log, replace
disp "DateTime: $S_DATE $S_TIME"

clear

local a "/Users/ramanyakkala/Desktop/OneDrive - California Polytechnic State University/Stata_Summer_Research/State Util"
cd "/Users/ramanyakkala/Desktop/OneDrive - California Polytechnic State University"
local files : dir "." files "*.txt"

foreach fname of local files {
        clear
        insheet using "`fname'"
        save `fname'.dta,replace
}
	* This dataset contains application numbers and whether they were ANDA (GENERIC) or not
use "`a'/Applications.txt.dta"
rename applno appl_no
tostring appl_no,replace
replace appl_no=substr("00000000",1,6-length(appl_no))+appl_no
	* The substr is so I can make all codes the same length as a code should be
save "`a'/Applications_new.txt.dta",replace


	* Making a Generic Dummy based on if they applied through ANDA (GENERIC)
use "`a'/applicat.dta"
merge m:1 appl_no using "`a'/Applications_new.txt.dta"
gen GENERIC = 0
replace GENERIC = 1 if strmatch(appltype,"ANDA")
rename _merge merge1
save "`a'/applicat_new.dta", replace


	* I merge the application to the Listing dta which will allow me to start crafting the NDC codes to merge
use "`a'/listings.dta"
merge 1:m listing_seq_no using "`a'/applicat_new.dta"
save "`a'/listings_merge.dta", replace


	* Dropping irrelevant columns so I can have mat space
keep listing_seq_no lblcode prodcode tradename appl_no appltype sponsorname GENERIC
duplicates drop listing_seq_no prodcode,force
save "`a'/listings_merge_unique.dta", replace

use "`a'/packages_old.dta"
merge m:1 listing_seq_no using "`a'/listings_merge_unique.dta"
save "`a'/packages_old_merge.dta",replace

	* Process of me connecting the three seperate variables that make up the NDC variable
clear
use "`a'/packages_old_merge.dta"
gen prodcode_new = ""

	* The code had *'s which I ASSUMED were place-holders for 0's (makes most sense) and replaced them with 0's
replace prodcode_new = substr(prodcode,2,.) if strpos(prodcode,"*")>0
replace prodcode_new = substr(prodcode,1,.) if strpos(prodcode,"*")==0
replace prodcode_new = substr("00000000",1,4-length(prodcode_new))+prodcode_new
drop prodcode
gen newndc = lblcode+prodcode_new+pkgcode
replace newndc = substr(newndc,2,.)
order newndc, a(listing_seq_no)
replace newndc = subinstr(newndc, "*", "0",.) 
duplicates drop newndc,force
save "`a'/packages_old_merge_ndc.dta",replace

import delimited "`a'/Drug_Products_in_the_Medicaid_Drug_Rebate_Program.csv", stringcols(4) clear 
gen GENERIC = 0
replace GENERIC = 1 if codstatus == "01"
*COD STATUS 01 MEANS ANDA
duplicates drop ndc GENERIC, force
duplicates tag ndc, gen (tag)
drop if tag == 1
*THERE ARE DUPLICATE NDC WITH DIFFERING CODSTATUS; DON'T KNOW HOW TO DEAL WITH THIS
rename ndc newndc
save "`a'/rebate_more_ndc.dta",replace

use "`a'/finished_aggregate.dta"
merge m:1 newndc using "`a'/packages_old_merge_ndc.dta", keepusing(GENERIC) update
rename _merge merge5
count if GENERIC == .
merge m:1 newndc using "`a'/rebate_more_ndc.dta", keepusing(GENERIC) update
rename _merge merge6
count if GENERIC == .
count

*Updating old 0's into 1's
replace GENERIC = 1 if merge3 == 5
replace GENERIC = 1 if merge5 == 5
replace GENERIC = 1 if merge6 == 5
save "`a'/finished_aggregate_more.dta", replace
