/*------------------------------------------------------------------------------
Purpose: Demonstrate FWL approach in Stata for an example where we are trying to
visualize the relationship between weight of a car and its mpg, controlling for
foreign vs domestic make 

Created: Nico Rotundo 2024-11-20
------------------------------------------------------------------------------*/
* Assign global for desired format 
global fmt %5.4f

* Set seed 
set seed 212354

* Import auto dataset
sysuse auto, clear 

* Check unique identifiers 
isid make

* Generate a population weight variable 
	* (just to illustrate how to approach this using weights in the regression)
* Drawing from a uniform distribution from 1-100
g population_weight = runiform(1, 100)
replace population_weight = round(population_weight)

/*------------------------------------------------------------------------------
Run regression and store estimates (just to display on graph)
------------------------------------------------------------------------------*/
* Run regression 
reghdfe mpg weight [aw=population_weight], absorb(i.foreign)

* Store slope and slope se for X variable of interest, and the constant 
local slope = _b[weight]
local slope_se = _se[weight]
local cons = _b[_cons]

* Generate slope local
local eq = `"Slope = `:display ${fmt} `slope'' (`:display ${fmt} `slope_se'')"'
di "`eq'"

* Confirm estimation sample is every observation in the current dataset 
assert e(sample) == 1 

* Save tempfile of current data 
tempfile data
save `data'

/*------------------------------------------------------------------------------
Implement FWL
------------------------------------------------------------------------------*/
* Residualize key LHS and RHS variable 
foreach variable in mpg weight {
	
	* Regress each variable on controls 
	reghdfe `variable' [aw=population_weight], absorb(i.foreign) resid
	
	* Save residuals 
	predict `variable'_r, residual
	
	* Add mean back in 
	sum `variable' [aw=population_weight]
	replace `variable'_r = `variable'_r + `r(mean)'
	
}

* Generate 20 bins for the x-variable residual 
fastxtile bin = weight_r [aw=population_weight], nq(20)

* Obtain mean of y-variable and x-variable residual for the 20 bins 
collapse (mean) mpg_r weight_r [aw=population_weight], by(bin)

* Generate binscatter 
tw /// 
	(scatter mpg_r weight_r, mcolor("scheme p1") msymbol(circle)) ///
	(function `slope' * x + `cons', range(weight_r) lcolor("scheme p1")) ///
	(connected mpg_r weight_r if bin==-9, mcolor("scheme p1") lcolor("scheme p1")) ///
	, ///
	${title_slides} ///
	ytitle("MPG (Residualized)") ///
	xtitle("Weight (Residualized)") ///
	ylabel(, nogrid angle(horizontal)) ///
	legend(label(3 "`eq'") ///
		order(3) symx(7) size(*.75) colgap(8) col(1) pos(1) ring(0) region(fcolor(none)))

/*------------------------------------------------------------------------------
Check output using binscatter command; the plot here should line up with the
above
------------------------------------------------------------------------------*/
* Import data from above 
use `data', clear 

* Run binscatter 
binscatter mpg weight [aw=population_weight], absorb(foreign) reportreg
