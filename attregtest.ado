*!   attregtest v1.3.0  GHO10May2021


program attregtest, eclass 
	version    13
	syntax     varlist(min=1 numeric) [if] [in], treatvar(varlist numeric max=1) respvars(varlist numeric  min=1)  [ vce(passthru) stratavar(varlist numeric max=1) timevar(varlist numeric fv max=1) export(string)] 

	marksample touse, novarlist
	local      res   p_IVP F_IVP  p_IVR F_IVR p_IVR2 F_IVR2
	tempname   `res' 
	
	
* ==========================
*		WARNINGS
* ==========================
	
	local noutcomes: word count `varlist'
	local nresponse: word count `respvars'
	
		if `noutcomes'!=`nresponse' {
			display in red "Error: the number of response variables must be equal to the number of outcome variables"
			exit
		}
	
	
	qui: count if `treatvar'==0
		if `r(N)'==0 {
			display in red "Error: the reference treatment (or control group) must take the value of zero"
			exit
		}
		
	foreach var in `respvars' {
		qui: count if `var'==0
		if `r(N)'==0 {
			display in red "Error: response variable `var' must take the value of zero for attritors"
			exit
		}
	}
	
	cap: ds response
	local nwords :  word count `r(varlist)'
		if `nwords'>0 {
			display in red "Error: none of the variables in the dataset can be named response"
			exit
		}


* =========================================
* COMPLETELY OR CLUSTER RANDOMIZED TRIALS 
* =========================================

	
if 	"`stratavar'"=="" {	

		
	* -------------------------------
	* LOCALS WITH NAMES AND VALUES
	* -------------------------------
	
	*Store the values of the treatment variable in local "treatlevels"
	qui:	   levelsof  `treatvar', local(treatlevels)

	*Store the G number of treatment groups (including the control group) in local "ngroups"
	local      ngroups: word count `treatlevels'

	*Store name of baseline outcomes in local "outcomes"
	gettoken    first rest: varlist
	local       outcomes "`first' `rest'"

	*Store name of response variables in local "response"
	gettoken    first rest: respvars
	local       responses "`first' `rest'"

	*---------------------------------
	* GENERATE TREATMENT VARIABLES 
	*---------------------------------

	* Generate dummy variables for all treatment groups & store this varlist in  local "treatvars"
	foreach      l in `treatlevels' {
	    qui: gen 	`treatvar'`l'=cond(`treatvar'==`l',1,0) 
		qui: replace  `treatvar'`l'=. if `treatvar'==.
		local    treatvars "`treatvars' `treatvar'`l'"
	}
	
	* Group of all dummy variables for treatment groups,  excluding the first category
	gettoken    first rest: treatvars
	local       treatvars_minus1 "`rest'"

	
	
	*------------------------------------------------------------------------
	* CONDUCT THE TESTS AND SAVE ESTIMATES AND SCALARS FOR OUTPUT TABLE
	* Note: use response variable that is relevant for each outcome, assuming
	* that order of response vars equals order of outcome variables
	*------------------------------------------------------------------------
	
	local i=0
	eststo clear
	foreach out of local outcomes { 
	
	
		local i=`i'+1
		local respvar: word `i' of `responses'
		qui: display "`respvar'"
		qui: gen response=`respvar'
				
		capture macro drop _intresp _ivr_vars _ivr_null _ivp_vars _ivp_null 
		
		
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		* GENERATE TREATMENT/RESPONSE INTERACTIONS
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		
		* Store list of interactions in local "intresp"
		
		foreach      g in `treatvars_minus1' {
			gen		 `g'Xresponse=`g'*response
			local     intresp "`intresp' `g'Xresponse"
		}
		
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~	
		* SAVE NULL HYPOTHESES IN LOCALS: TEST OF IV-R
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		
		local     ivr_vars "`treatvars_minus1' `intresp'"
		
		foreach 	v in `ivr_vars' {
			local   ivr_null " `ivr_null' = `v'"
		}	
		local ivr_null "`ivr_null'=0"
		gettoken   first ivr_null: ivr_null, parse(" ")


		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~	
		* SAVE NULL HYPOTHESES IN LOCALS: TEST OF IV-P
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		
		local     ivp_vars "`treatvars_minus1' response `intresp'"
		
		foreach 	v in `ivp_vars' {
			local   ivp_null " `ivp_null' = `v'"
		}	
		local ivp_null "`ivp_null'=0"
		gettoken   first ivp_null: ivp_null, parse(" ")

	
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		* REGRESSION TESTS FOR THE CASE WHERE OPTION TIMEVAR IS NOT SPECIFIED
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		
		if "`timevar'"=="" {
	

			*Estimation with constant
			   qui: regress	  `out'  `intresp'  `treatvars_minus1' response if `touse' ,  `vce'
			
				*Test of IV-R
				 qui: test   "`ivr_null'"    
				 qui: estadd scalar    F_IVR=r(F)
				 qui: estadd scalar    p_IVR=r(p)		
				
				*Test of IV-P
				qui: test "`ivp_null'"
				qui: estadd scalar    F_IVP=r(F)
				qui: estadd scalar    p_IVP=r(p)
				
			qui: estimates  store `out', title("`out'")
		}
		
		
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		* REGRESSION TESTS FOR THE CASE WHERE OPTION TIMEVAR IS SPECIFIED
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

		if "`timevar'"!="" {
	

			*Estimation with constant
			 qui xi: regress	  `out' `intresp' `treatvars_minus1' response i.`timevar'  if `touse' , nocons  `vce'
			
				*Test of IV-R
				qui: test   "`ivr_null'"    
				qui: estadd scalar    F_IVR=r(F)
				qui: estadd scalar    p_IVR=r(p)		
				
				*Test of IV-P
				qui: test "`ivp_null'"
				qui: estadd scalar    F_IVP=r(F)
				qui: estadd scalar    p_IVP=r(p)
				
			qui: estimates  store `out', title("`out'")
		}
		
		
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		* CALCULATES THE MEAN BASELINE OUTCOME FOR CONTROL ATTRITORS 
		* Note: assumes control group corresponds to first category (value=0) 
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

		qui: levelsof  `treatvar', local(treatlevels)
		qui: gettoken    first rest: treatlevels
		qui: sum `out' if `treatvar'==`first' & response==0
		qui: estadd scalar meanCA=r(mean)
		
		
		cap:   drop  `intresp'  response 
		
	}
			
	*------------------------
	* DROP CREATED VARIABLES
	*------------------------

		cap:   drop `treatvars'   _est*

	
	*-----------------------
	* PRODUCE OUTPUT TABLE
	*-----------------------
	  
	  	   if "`vce'"=="" {
			
				if "`timevar'"=="" {
				esttab `outcomes' , drop(_cons) cells(b(fmt(3)) se(par fmt(3))) ///
				legend label    nostar            ///
				stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
				addnotes("(+) Mean baseline outcome control attritors")
				}
			
				if "`timevar'"!="" {
				esttab `outcomes' , cells(b(fmt(3)) se(par fmt(3))) ///
				legend label    nostar            ///
				stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
				addnotes("(+) Mean baseline outcome control attritors")
				}
			
		   }

		   
	  	  if "`vce'"!="" {
		  
				if "`timevar'"=="" {
				esttab `outcomes', drop(_cons) cells(b(fmt(3)) se(par fmt(3))) ///
				legend label   nostar             ///
				stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
				addnotes("(+) Mean baseline outcome control attritors" "Standard errors are `vce'")
				}
			
				if "`timevar'"!="" {
				esttab `outcomes',  cells(b(fmt(3)) se(par fmt(3))) ///
				legend label   nostar             ///
				stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
				addnotes("(+) Mean baseline outcome control attritors" "Standard errors are `vce'")
				}		
		   }


		   
	*-----------------------
	* EXPORT OUTPUT TABLE
	*-----------------------
	
	  if "`export'"!=""{
	  
			
			if "`vce'"=="" {
			
				if "`timevar'"=="" {
				esttab `outcomes' using "`export'", replace drop(_cons) cells(b(fmt(3)) se(par fmt(3))) ///
				legend label    nostar            ///
				stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
				addnotes("(+) Mean baseline outcome control attritors")
				}
			
				if "`timevar'"!="" {
				esttab `outcomes' using "`export'", replace cells(b(fmt(3)) se(par fmt(3))) ///
				legend label    nostar            ///
				stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
				addnotes("(+) Mean baseline outcome control attritors")
				}
			
		   }

		   
		   
	  	  if "`vce'"!="" {
		  
				if "`timevar'"=="" {
				esttab `outcomes' using "`export'", replace drop(_cons) cells(b(fmt(3)) se(par fmt(3))) ///
				legend label   nostar             ///
				stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
				addnotes("(+) Mean baseline outcome control attritors" "Standard errors are `vce'")
				}
			
				if "`timevar'"!="" {
				esttab `outcomes' using "`export'", replace cells(b(fmt(3)) se(par fmt(3))) ///
				legend label   nostar             ///
				stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
				addnotes("(+) Mean baseline outcome control attritors" "Standard errors are `vce'")
				}		
		   }

	  
	  }
	  

}


* =========================================
*	 STRATIFIED RANDOMIZED TRIALS 
* =========================================


if "`stratavar'"!="" {

	* -------------------------------
	* LOCALS WITH NAMES AND VALUES
	* -------------------------------

	
	*Store the values of the treatment variable in local "treatlevels"
	qui:	   levelsof  `treatvar', local(treatlevels)
	
	*Store the G number of treatment groups (including the control group) in local "ngroups"
	local      ngroups: word count `treatlevels'
		
	*Store name of baseline outcomes in local "outcomes"
	gettoken    first rest: varlist
	local       outcomes "`first' `rest'"
	
	*Store the values of the strata variable in local "stratalevels"
	qui:	   levelsof  `stratavar', local(stratalevels)
	
	*Store S number of strata groups in local nstrata
	local      sgroups: word count `stratalevels'
	
	*Store name of response variables in local "response"
	gettoken    first rest: respvars
	local       responses "`first' `rest'"

	

	* ----------------------------------------------------------
	* GENERATE TREATMENT, STRATA, AND TREATMENT STRATA VARIABLES
	* ----------------------------------------------------------

	* Generate dummy variables for all treatment groups (including control) & store this varlist in  local "treatvars"
	foreach      l in `treatlevels' {
	    qui:     gen 	`treatvar'`l'=cond(`treatvar'==`l',1,0) 
		cap:     replace  `treatvar'`l'=. if `treatvar'==.
		local    treatvars "`treatvars' `treatvar'`l'"
	}
	
	
	* Generate dummy variables for all strata groups  & store this varlist in  local "stratavars"
	foreach      l in `stratalevels' {
	    qui:    gen 	`stratavar'`l'=cond(`stratavar'==`l',1,0) 
		cap:    replace  `stratavar'`l'=. if `stratavar'==.
		local    stratavars "`stratavars' `stratavar'`l'"
	}
	
	
	* Group of all dummy variables for treatment groups,  excluding the first category
	gettoken    first rest: treatvars
	local       treatvars_minus1 "`rest'"

	
	* Group of all dummy variables for strata groups,  excluding the first category
	gettoken    first rest: stratavars
	local       stratavars_minus1 "`rest'"


	
	*Group treatment/strata interactions: 
	foreach      s in `stratavars' {
	foreach      g in `treatvars_minus1' {
		qui:     gen `g'X`s'=`g'*`s'
		local     int_treatstrata`s' "`int_treatstrata`s'' `g'X`s'"		
	}
		local     int_treatstrata "`int_treatstrata' `int_treatstrata`s'' "		
	}

	
	
	*------------------------------------------------------------------------
	* CONDUCT THE TESTS AND SAVE ESTIMATES AND SCALARS FOR OUTPUT TABLE
	* Note: use response variable that is relevant for each outcome, assuming
	* that order of response vars equals order of outcome variables
	*------------------------------------------------------------------------
	
	local i=0
	eststo clear
	foreach out of local outcomes { 
	
	
		local i=`i'+1
		local respvar: word `i' of `responses'
		qui: display "`respvar'"
		qui: gen response=`respvar'
				
		capture macro drop _int_treatresp _int_respstrata _int_trs  _ivr_vars _ivr_null _ivp_vars _ivp_null _ivr_vars2 _ivr_null2 _ivp_vars2 _ivp_null2
		
		
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		* GENERATE TREATMENT/RESPONSE INTERACTIONS
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		
		*Group of interactions: treatment/response
		foreach      g in `treatvars_minus1' {
			gen		 `g'Xresponse=`g'*response
			local     int_treatresp "`int_treatresp' `g'Xresponse"		
		}

		*Group of interactions: strata/response
		foreach      s in `stratavars' {
			qui: 	 gen	responseX`s'=response*`s'
			local     int_respstrata "`int_respstrata' responseX`s'"		
		}

	
		* Group of interactions:  treatment/respondents/strata
		foreach      s in `stratavars' {
		foreach      g in `treatvars_minus1' {
			gen		 `g'XresponseX`s'=`g'*response*`s'
			local     int_trs`s' "`int_trs`s'' `g'XresponseX`s'"		
		}
			local     int_trs "`int_trs' `int_trs`s''"
		}
		

				
	
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~	
		* SAVE NULL HYPOTHESES IN LOCALS: FULLY STURATED MODEL
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

		* TEST OF IV-R
		
		local   ivr_vars "`int_treatstrata' `int_trs'"
		
		foreach 	v in `ivr_vars' {
			local   ivr_null " `ivr_null' = `v'"
		}	
		local ivr_null "`ivr_null'=0"
		gettoken   first ivr_null: ivr_null, parse(" ")
		
		
	
		* TEST OF IV-P

		local   ivp_vars " `int_treatstrata' `int_respstrata' `int_trs'"
		
		foreach 	v in `ivp_vars' {
			local   ivp_null " `ivp_null' = `v'"
		}	
		local ivp_null "`ivp_null'=0"
		gettoken   first ivp_null: ivp_null, parse(" ")


	
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~	
		* SAVE NULL HYPOTHESES IN LOCALS: MODEL W STRATA FE ONLY
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


		*Test of IV-R
	
		local   ivr_vars2 "`treatvars_minus1' `int_treatresp'"
		
		foreach 	v in `ivr_vars2' {
			local   ivr_null2 " `ivr_null2' = `v'"
		}	
		local ivr_null2 "`ivr_null2'=0"
		gettoken   first ivr_null2: ivr_null2, parse(" ")
		

	
	
		*Test of IV-P
		
		local   ivp_vars2 "`treatvars_minus1' response `int_treatresp'"
		
		foreach 	v in `ivp_vars2' {
			local   ivp_null2 " `ivp_null2' = `v'"
		}	
		local ivp_null2 "`ivp_null2'=0"
		gettoken   first ivp_null2: ivp_null2, parse(" ")


	
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		* REGRESSION TESTS FOR THE CASE WHERE OPTION TIMEVAR IS NOT SPECIFIED
		* Note: three regressions -- see details in Section B of paper
		*	(1) Fully saturated model 
		*	(2) Strata FE only model: specification for IV-R test
		*	(3) Strata FE only model: specification for IV-P test
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	
		cap:  gen `F_IVR'=.
		cap:  gen `p_IVR'=.
		cap:  gen `F_IVR2'=.
		cap:  gen `p_IVR2'=.
		cap:  gen `F_IVP'=.
		cap:  gen `p_IVP'=.
	
		if "`timevar'"=="" {	
		
			 * (1) ESTIMATION OF FULLY SATURATED MODEL
			 
			 qui: regress	  `out' `stratavars' `int_respstrata' `int_treatstrata'   `int_trs'   if `touse' , nocons  `vce'

				*Test of IV-R
				qui: test      `ivr_null' 
				qui: replace    `F_IVR'=r(F)
				qui: replace    `p_IVR'=r(p)

				
				*Test of IV-P
				qui: test       `ivp_null'
				qui: replace    `F_IVP'=r(F)
				qui: replace    `p_IVP'=r(p)
				

		
			* (2) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-R TEST
			 
			 qui: regress	  `out'  `int_respstrata' `treatvars_minus1'  `int_treatresp' `stratavars'  if `touse' ,  nocons `vce'
			
				*Test of IV-R
				qui: test     	`ivr_null2'
				qui: replace    `F_IVR2'=r(F)
				qui: replace    `p_IVR2'=r(p)


			
			* (3) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-P TEST
			
			qui: regress	  `out'  `int_treatresp' `treatvars_minus1' response `stratavars'  if `touse' ,  nocons `vce'
			qui: estimates  store `out', title("`out'")

				*Test of IV-P
				qui: test    `ivp_null2'
				qui: estadd scalar    Fivp2=r(F)
				qui: estadd scalar    pivp2=r(p)
				
				
				qui: sum `p_IVR'
				qui: estadd scalar p_IVR=r(mean)
				
				qui: sum `p_IVP'
				qui: estadd scalar p_IVP=r(mean)
				
				
				qui: sum `p_IVR2'
				qui: estadd scalar pivr2=r(mean)
				
				qui: sum `F_IVR2'
				qui: estadd scalar Fivr2=r(mean)


			qui: estadd local modelfe ""
			qui: estadd local satmodel ""
			
			}
		
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		* REGRESSION TESTS FOR THE CASE WHERE OPTION TIMEVAR IS SPECIFIED
		* Note: three regressions -- see details in Section B of paper
		*	(1) Fully saturated model 
		*	(2) Strata FE only model: specification for IV-R test
		*	(3) Strata FE only model: specification for IV-P test
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

		if "`timevar'"!="" {	
	
		 * (1) ESTIMATION OF FULLY SATURATED MODEL
		 qui xi: regress	  `out'   `stratavars' `int_respstrata' `int_treatstrata'   `int_trs' i.`timevar' if `touse' , nocons `vce'

		
			*Test of IV-R
			qui: test      `ivr_null' 
			qui: replace    `F_IVR'=r(F)
			qui: replace    `p_IVR'=r(p)

			
			*Test of IV-P
			qui: test       `ivp_null'
			qui: replace    `F_IVP'=r(F)
			qui: replace    `p_IVP'=r(p)
			
		
		* (2) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-R TEST
		qui: regress	  `out'  `int_respstrata' `treatvars_minus1'  `int_treatresp' `stratavars' i.`timevar'  if `touse' ,  nocons `vce'
		
			*Test of IV-R
			qui: test     	`ivr_null2'
			qui: replace    `F_IVR2'=r(F)
			qui: replace    `p_IVR2'=r(p)


		* (3) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-P TEST
		qui: regress	  `out' `int_treatresp' `treatvars_minus1' response `stratavars' i.`timevar'  if `touse' , nocons `vce'
		qui: estimates  store `out', title("`out'")
		
		
			*Test of IV-P
			qui: test    `ivp_null2'
			qui: estadd scalar    Fivp2=r(F)
			qui: estadd scalar    pivp2=r(p)
			
			
			qui: sum `p_IVR'
			qui: estadd scalar p_IVR=r(mean)
			
			qui: sum `p_IVP'
			qui: estadd scalar p_IVP=r(mean)
			
			
			qui: sum `p_IVR2'
			qui: estadd scalar pivr2=r(mean)
			
			qui: sum `F_IVR2'
			qui: estadd scalar Fivr2=r(mean)



		qui: estadd local modelfe ""
		qui: estadd local satmodel ""
		}
	
	
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		* CALCULATES THE MEAN BASELINE OUTCOME FOR CONTROL ATTRITORS 
		* Note: assumes control group corresponds to first category (value=0) 
		*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		qui: levelsof  `treatvar', local(treatlevels)
		qui: gettoken    first rest: treatlevels
		qui: sum `out' if `treatvar'==`first' & response==0
		qui: estadd scalar meanCA=r(mean)

	cap:   drop  `int_treatresp' `int_respstrata' `int_trs' response
	
	}
			

	*------------------------
	* DROP CREATED VARIABLES
	*------------------------
		cap:   drop `treatvars' `stratavars' `int_treatstrata'  _est* 
		

	 		
	*------------------------
	* PRODUCE OUTPUT TABLE
	*------------------------
	
	  if "`vce'"=="" {
		esttab `outcomes', cells(b(fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
		legend label   nostar              ///
		stats(meanCA satmodel  p_IVR p_IVP modelfe pivr2 pivp2, fmt(3 0 3 3 0 3 3 0) ///
		label("Control Attritors(+)" "FULLY SATURATED" "Test of IV-R (p-val)" "Test of IV-P (p-val)" "FIXED EFFECTS ONLY"  "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
		addnotes("Coefficients correspond to the model with strata fixed effects only" "(+) Mean baseline outcome control attritors")
	   }
	   
	  if "`vce'"!="" {
		esttab `outcomes', cells(b( fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
		legend label   nostar              ///
		stats(meanCA satmodel  p_IVR p_IVP modelfe pivr2 pivp2, fmt(3 0 3 3 0 3 3 0) ///
		label("Control Attritors(+)" "FULLY SATURATED" "Test of IV-R (p-val)" "Test of IV-P (p-val)" "FIXED EFFECTS ONLY"  "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
		addnotes("Coefficients correspond to the model with strata fixed effects only" "(+) Mean baseline outcome control attritors" "Standard errors are `vce'")
	   }
	   
	   
	*------------------------
	* EXPORT OUTPUT TABLE
	*------------------------
	
	  if "`export'"!=""{
	  
		  if "`vce'"=="" {
			esttab `outcomes' using "`export'", replace cells(b( fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
			legend label    nostar             ///
			stats(meanCA satmodel  p_IVR p_IVP modelfe pivr2 pivp2, fmt(3 0 3 3 0 3 3 0) ///
			label("Control Attritors(+)" "FULLY SATURATED" "Test of IV-R (p-val)" "Test of IV-P (p-val)" "FIXED EFFECTS ONLY"  "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
			addnotes("Coefficients correspond to the model with strata fixed effects only" "(+) Mean baseline outcome control attritors")
		   }
		   
		   if "`vce'"!="" {
			esttab `outcomes' using "`export'", replace cells(b( fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
			legend label   nostar              ///
			stats(meanCA satmodel  p_IVR p_IVP modelfe pivr2 pivp2, fmt(3 0 3 3 0 3 3 0) ///
			label("Control Attritors(+)" "FULLY SATURATED" "Test of IV-R (p-val)" "Test of IV-P (p-val)" "FIXED EFFECTS ONLY"  "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
			addnotes("Coefficients correspond to the model with strata fixed effects only" "(+) Mean baseline outcome control attritors" "Standard errors are `vce'")
		   }
		}
	
}

end
