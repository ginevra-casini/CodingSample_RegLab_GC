// This dofile uses 2015-2020 waves of the CPS-MORG to extract state by year union wage premia to keep for further analyses, then it averages the premia using state-by-year employment as weights to obtain US-wide premia, and finally plots them over the years
// Created: 22/11/2024
// Last updated: 23/11/2024
// Ginevra Casini

// Set globals for directories
global maindir "/Users/ginevracasini/Desktop/PreDocs/Stanford/RegLab/Coding Sample/"
global data "${maindir}data/"
global figures "${maindir}figures/"

// Load merged and cleaned CPS-MORG waves (2010-2022)
use "${data}cpsmorg_final.dta", clear 

// Generate age squared
gen age2 = age^2
label var age2 "Age squared"

// Generate logged wage
gen logwage = log(wage)
label var logwage "Logarithm of hourly wage"

// Store year range
sum year 
local beg = r(min)
local end = r(max)
local time `beg'/`end'

// Store states 
levelsof statenum, local(states)

// Calculate unconditional and conditional union premia
foreach state of local states {
	forvalue t = `time'{
		di "Working on: state `state' & year `t'"
		
		* 1) Unconditional premium
		qui: reg logwage i.union if statenum == `state' & year == `t' [aw=earnwt], cluster(statenum)
		local upremium = _b[1.union]
		
		* 2) Conditional premium
		qui: reg logwage i.union i.sex age age2 i.race i.education ///
		if statenum == `state' & year == `t' [aw=earnwt], cluster(statenum)
		local upremium_cond = _b[1.union]
		
		// Save estimation results into a matrix 
		if `state' == 1 & `t' == `beg' {
			matrix upremia = (`state', `t', `upremium', `upremium_cond')
		} 
		else {
			matrix upremia = (upremia \ (`state', `t', `upremium', `upremium_cond'))
		}
	}
}

// Turn matrix into dataset and save data
preserve

svmat upremia

keep upremia* empcount

rename upremia1 statenum
rename upremia2 year		
rename upremia3 upremium
rename upremia4 upremium_cond

keep if upremium != .

assert upremium != . & upremium_cond != .

save "${data}unionpremia.dta", replace 
restore

// Collapse data using state-by-year employment counts as weights and plot premia overtime 
use "${data}unionpremia.dta", clear 

collapse (mean) upremium* [aw=empcount], by(year)

grstyle init
grstyle set plain, horizontal compact minor
grstyle set symbolsize small
grstyle set legend 6

twoway ///
    (connected upremium year,  lcolor(blue) mcolor(blue)) ///
    (connected upremium_cond year, lcolor(red) mcolor(red)), ///
    xtitle("Year") xsc(titlegap(*7)) ///
    ytitle("Union Wage Premium")  ///
    legend(order(1 "Unconditional Premium" 2 "Conditional Premium") size(small)) ///
    ylabel(0(0.05)0.4, labsize(small) angle(horizontal)) yscale(range(0 0.4)) ///
    xscale(range(2015 2020)) xla(2015(1)2020, labsize(small))
	graph save "${figures}Union_wage_premium", replace
	graph export "${figures}Union_wage_premium.pdf", replace  

