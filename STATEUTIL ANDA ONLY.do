*NDC data - GET STATEUTIL DATA READY / NOT RECOGNIZING AUTHORIZED GENERIC AS GENERIC
*link to data
*Created: July 16, 2018
*Last updated: July 16, 2018
		
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

log using STATEUTIL_ANDA_`today'.log, replace
disp "DateTime: $S_DATE $S_TIME"

clear

* THIS SECTION IMPORTS ALL THE CSV || REMOVE ASTERIKS IF YOU WANT TO IMPORT

*forval t=2006/2017 {
	*clear
	*import delimited `a'/State_Drug_Utilization_Data_`t'.csv, stringcols(20)
	*drop if strmatch(suppressionused,"true")
	*save "`a'/`t'.dta",replace
	//change directory based on where you want to save it
	*}

* THIS DESTRINGS AND TOSTRINGS CERTAIN VARIABLES SO WE CAN APPEND	

*forval t=2006/2017 {
	*clear
	*use `a'/`t'.dta
	*destring packagesize, replace
	*tostring productcode, replace
	*save "`a'/`t'.dta",replace
	//change directory based on where you want to save it
	*}

* THIS APPENDS THE STATEUTIL CSV	
	
use "`a'/2006.dta"
// start with 2006.dta in your STATA

forval t=2007/2017 {
	append using "`a'/`t'.dta"
	
	}
	
*THIS MAKES THE NDC AN 11 DIGIT NUMBER THROUGH ADDING LEADING ZEROS THAT WERE LOST	
	
gen newndc = substr("0000000", 1, 11 - length(ndc)) + ndc
drop if strmatch(state,"XX")
save "`a'/aggregate_stateutil.dta",replace

*THIS IMPORTS THE PRODUCT AND PACKAGE DATA
clear
import delimited "`a'/product.txt
save "`a'/product.dta", replace

clear
import delimited "`a'/package.txt
save "`a'/package.dta", replace

* THIS MAKES MARKS OBS THAT ARE GENERIC THROUGH ANDA APPROVAL OR AUTHORIZED GENERICS

use "`a'/product.dta"

gen GENERIC = 0
replace GENERIC = 1 if strpos(marketingcategoryname,"ANDA")>0

drop if strmatch(productid,"")

gen OTC=0
replace OTC = 1 if strpos(producttypename,"OTC")>0

save "`a'/Generic_product.dta",replace

*THIS IS SETTING THE PRODUCT DATA BY CONVERTING 10 DIGIT NDC TO 11 DIGIT

use "`a'/package.dta"

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
order newndc, a(productndc)

save "`a'/new_ndc_package.dta",replace

*IMPORT AND CLEAN NDC SPL DATA

clear
import delimited "`a'/Comprehensive NDC SPL Data Elements File.csv"
save "`a'/NDC_SPL_raw.dta",replace

clear
import delimited "`a'/firms.csv"
tostring lblcode,replace
save "`a'/firms_raw.dta",replace

use "`a'/NDC_SPL_raw.dta"
merge m:1 lblcode using "`a'/firms_raw.dta"
drop if strmatch(firm_name,"")
save "`a'/NDC_SPL_firms_raw.dta",replace

rename _merge merge1

gen GENERIC = 0
replace GENERIC = 1 if strpos(marketingcategory,"ANDA")>0

gen OTC = 0
replace OTC = 1 if strpos(marketingcategory,"OTC")>0

gen newndc = substr("000000000",1,11-length(ndc11))+ndc11
duplicates drop newndc GENERIC, force

save "`a'/Generic_NDC_SPL_firms.dta",replace

*MERGE PRODUCT AND PACKAGE AND MERGE THAT WITH STATE UTIL

clear
use "`a'/new_ndc_package.dta"

merge m:1 productid using "`a'/Generic_product.dta", keepusing(GENERIC)
drop if strmatch(newndc,"")
rename _merge merge1
merge m:1 productid using "`a'/Generic_product.dta", keepusing(OTC)
drop if strmatch(newndc,"")
duplicates drop newndc,force
save "`a'/merge_package_product.dta",replace

clear
use "`a'/aggregate_stateutil.dta"
merge m:1 newndc using "`a'/merge_package_product.dta",keepusing(GENERIC)
rename _merge merge1
merge m:1 newndc using "`a'/merge_package_product.dta",keepusing(OTC)
rename _merge merge2
save "`a'/generic_aggregate_stateutil.dta",replace

*MERGE SPL DATA WITH STATE UTIL

clear

use "`a'/generic_aggregate_stateutil.dta"
merge m:1 newndc using "`a'/Generic_NDC_SPL_firms.dta", keepusing(GENERIC) update
rename _merge merge3
merge m:1 newndc using "`a'/Generic_NDC_SPL_firms.dta", keepusing(OTC) update
drop if strmatch(ndc,"")
rename _merge merge4
drop if strmatch(state,"XX")
*UPDATING OLD'0's TO NEW 1's
replace GENERIC = 1 if merge3 == 5
replace OTC = 1 if merge4 == 5
save "`a'/finished_aggregate", replace




