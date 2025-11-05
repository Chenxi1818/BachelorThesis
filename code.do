***************************
*** prepare data 
***************************

* Set project directory once to avoid hard-coded paths
global proj "E:\24老年社会参与和心理健康"
cd "$proj\charls2020\data"

/* CHARLS 2020: Demographic Data */

use "Demographic_Background", clear

* Keep only self-respondents
keep if proxy_2 == 2 | missing(proxy_2)

* Keep elderly aged 60–90
keep if inrange(xrage, 60, 90)
gen age = xrage
gen dum_age = inrange(xrage, 60, 74)
label var dum_age "=1 if 60–74 (young-old)"

* Residence: village = 1
gen resid = (ba008 == 3)
label var resid "=1 if rural (village)"
label define resid_va 0 "Urban" 1 "Rural", replace
label values resid resid_va

* Gender: female = 1
gen gender = (xrgender == 2)
label var gender "=1 if female"
label define gender_va 0 "Male" 1 "Female", replace
label values gender gender_va

* Marital status: with partner = 1
gen partner = (xrpartner == 1)
label var partner "=1 if has spouse/partner"

* Medical insurance
gen medi = (ba016 != 3)
label var medi "=1 if has social medical insurance"

* Living alone
gen lone = (ba018 != 0)
label var lone "=1 if lived alone in 2020H1"

save "$proj\charls2020\Demo_ID", replace

/* CHARLS 2020: Health and Functioning */

use "Health_Status_and_Functioning.dta", clear
merge 1:1 ID using "$proj\charls2020\Demo_ID", keep(match) nogen

* Keep self-respondents
keep if proxy_5 == 2 | missing(proxy_5)

* Hospitalization in past year
gen hospital = (da007 == 1) if !missing(da007)
label var hospital "=1 if hospitalized in past year"

* Social participation
gen social = (da038_s9 != 9) if !missing(da038_s9)
label var social "=1 if participated socially last month"

* Internet use
gen inte = (da040 == 1)
label var inte "=1 if used internet last month"


* CES-D-10 Depression Scale

global deprelist dc016 dc017 dc018 dc019 dc020 dc021 dc022 dc023 dc024 dc025
foreach var of global deprelist {
    replace `var' = . if inlist(`var', 997, 999)
}

* Reverse-code positive items
recode dc016 dc017 dc018 dc019 dc021 dc022 dc024 dc025 (1=0)(2=1)(3=2)(4=3)
recode dc020 dc023 (1=3)(2=2)(3=1)(4=0)

egen depre = rsum($deprelist)
label var depre "CES-D-10 total score"
gen dum_depre = (depre >= 10)
label var dum_depre "=1 if CES-D-10 ≥10 (depressed)"

save "$proj\charls2020\Health_ID", replace

/* Family and Economic Info */

use "Family_Information.dta", clear
merge 1:m householdID using "$proj\charls2020\Health_ID", keep(match) nogen

gen numchid = xchildalivenum
label var numchid "Number of living children"
save "$proj\charls2020\Family_householdID", replace

* Employment
use "Work_Retirement.dta", clear
merge 1:1 ID using "$proj\charls2020\Family_householdID", keep(match) nogen
keep if proxy_7 == 2 | missing(proxy_7)
gen work = (fa004 == 1)
label var work "=1 if engaged in nonfarm work"
save "$proj\charls2020\Work_ID", replace

* Income / Poverty
use "Household_Income.dta", clear
merge 1:m householdID using "$proj\charls2020\Work_ID", keep(match) nogen
gen poor = (ge001_s6 == 0) if !missing(ge001_s6)
label var poor "=1 if poor household"
save "$proj\charls2020\Income_householdID", replace

/* CHARLS 2018: Education */

cd "$proj\charls2018\data"
use "Demographic_Background", clear
merge 1:1 ID using "$proj\charls2020\Income_householdID", keep(match) nogen

gen educ_2018 = (bd001_w2_4 >= 6)
label var educ_2018 "=1 if high school or above"
save "$proj\data\merged_2018_2020", replace

/* CHARLS 2011: Community Variables */

use "E:\数据\CHARLS\2011\community.dta", clear
keep if !missing(jb029_1_11_) & !missing(jb029_1_5_)
gen center = (jb029_1_11_ == 1) | (jb029_1_5_ == 1)
label var center "=1 if had senior center or chess room (2010)"

gen dance = (jb029_1_8_ == 1)
label var dance "=1 if had dance/exercise team"

gen exprop = (ja035 == 1) if inlist(ja035,1,2)
label var exprop "=1 if expropriated since 2000"

gen plain = (ja038 == 1)
label var plain "=1 if main terrain is plain"

gen pubres = (jb014 == 1)
label var pubres "=1 if public restroom present"

gen light = (jb020 >= 357) if !missing(jb020)
label var light "=1 if >357 days electricity in 2010"

duplicates drop communityID, force
save "$proj\charls2011\community", replace

* Merge all years

use "$proj\data\merged_2018_2020", clear
merge m:1 communityID using "$proj\charls2011\community", keep(match) nogen
save "$proj\data\merged_2018_2020_2011.dta", replace

***************************
*** analyze data 
***************************
use "$proj\data\merged_2018_2020_2011.dta", clear

global demo_vlist age resid gender partner educ_2018
global beha_vlist medi lone hospital inte work
global hous_vlist poor numchid
global comm_vlist exprop pubres light plain

/* descriptive analysis */

sum social depre social center dance $demo_vlist $beha_vlist $hous_vlist $comm_vlist

sum depre center dance $demo_vlist $beha_vlist $hous_vlist $comm_vlist if social==1

sum depre center dance $demo_vlist $beha_vlist $hous_vlist $comm_vlist  if social==0

ttest depre center dance $demo_vlist $beha_vlist $hous_vlist $comm_vlist , by(social)

/* baseline regression */

label variable social "Social participation"
label variable depre "Depression level"
label variable age "Age"
label variable resid "Residence"
label variable gender "Gender"
label variable partner "Partner"
label variable educ_2018 "Education level"
label variable medi "Health insurance"
label variable lone "Live alone"
label variable hospital "Hospitalization"
label variable inte "Internet use"
label variable work "Non-farm work"
label variable poor "Poor household"
label variable numchid "Children"
label variable exprop "Expropriation"
label variable pubres "Public restroom"
label variable light "Power supply"
label variable plain "Terrain"

label variable center "Center"
label variable dance "Dance"

reg depre social, robust
reg depre social $demo_vlist , robust
reg depre social $demo_vlist $beha_vlist , robust
reg depre social $demo_vlist $beha_vlist $hous_vlist , robust
reg depre social $demo_vlist $beha_vlist $hous_vlist $comm_vlist, robust

/* IV regression */

* over identification
ivreg2 depre $demo_vlist $beha_vlist $hous_vlist $comm_vlist (social = center dance), robust endog(social) 

* IV
ivreg2 depre $demo_vlist $beha_vlist $hous_vlist $comm_vlist (social = center), robust endog(social)

************************
*** robustness check
************************

/* Bootstrap */

bootstrap, reps(1000): ivreg2 depre $demo_vlist $beha_vlist $hous_vlist $comm_vlist (social = center), robust endog(social) 

/* heterogeneity */

* gender
codebook gender
ivreg2 depre age resid partner educ_2018   $beha_vlist $hous_vlist $comm_vlist (social = center) if gender == 1, robust 
ivreg2 depre age resid partner educ_2018   $beha_vlist $hous_vlist $comm_vlist (social = center) if gender == 0, robust 

* Marital status
codebook partner
sort partner
by partner: ivreg2 depre gender age resid educ_2018  $beha_vlist $hous_vlist $comm_vlist (social = center), robust

* education
codebook educ_2018
sort educ_2018
by educ_2018: ivreg2 depre gender age resid partner  $beha_vlist $hous_vlist $comm_vlist (social = center), robust

