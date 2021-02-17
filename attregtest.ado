*!   attregtest v1.0.0  GHO15feb2021


program attregtest, eclass 
	version    13
	syntax     varlist(min=1 numeric) [if] [in], treatvar(varlist numeric max=1) respvar(varlist numeric  max=1)  [ vce(passthru) stratavar(varlist numeric max=1) timevar(varlist numeric fv max=1) export(string)] 

	marksample touse
	local      res   p_IVP F_IVP  p_IVR F_IVR p_IVR2 F_IVR2
	tempname   `res' 
	
if "`stratavar'"=="" {	
		
	* 1) LOCALS WITH NAMES AND VALUES

	*Make sure respvar is a 1/0 variable
    cap:       replace `respvar'=0 if `respvar'!=1 & `respvar'!=.	
	
	*Store the values of the treatment variable in local "treatlevels"
	qui:	   levelsof  `treatvar', local(treatlevels)
	
	*Store the G number of treatment groups (including the control group) in local "ngroups"
	local      ngroups: word count `treatlevels'
		
	*Store name of baseline outcomes in local "outcomes"
	gettoken    first rest: varlist
	local       outcomes "`first' `rest'"
	

	* 2) GENERATE VARIABLES 

	* Generate dummy variables for all treatment groups & store this varlist in  local "treatvars"
	foreach      l in `treatlevels' {
	    gen 	`treatvar'`l'=cond(`treatvar'==`l',1,0) 
		cap: replace  `treatvar'`l'=. if `treatvar'==.
		local    treatvars "`treatvars' `treatvar'`l'"
	}
	
	* Group of all dummy variables for treatment groups,  excluding the first category
	gettoken    first rest: treatvars
	local       treatvars_minus1 "`rest'"

	
	* Group of interactions for respondents: store list of interactions in local "intresp"
	foreach      g in `treatvars_minus1' {
		gen		 `g'X`respvar'=`g'*`respvar'
		local     intresp "`intresp' `g'X`respvar'"
	}
	
	
		
	* 3) SAVE NULL HYPOTHESES IN LOCALS: TEST OV IV-R	
	
	local     ivr_vars "`treatvars_minus1' `intresp'"
	
	foreach 	v in `ivr_vars' {
		local   ivr_null " `ivr_null' = `v'"
	}	
	local ivr_null "`ivr_null'=0"
	gettoken   first ivr_null: ivr_null, parse(" ")

	
	* 4) SAVE NULL HYPOTHESES IN LOCALS: TEST OV IV-P	
	
	local     ivp_vars "`treatvars_minus1' `respvar' `intresp'"
	
	foreach 	v in `ivp_vars' {
		local   ivp_null " `ivp_null' = `v'"
	}	
	local ivp_null "`ivp_null'=0"
	gettoken   first ivp_null: ivp_null, parse(" ")

	
	
	* 5) CONDUCT THE TESTS AND SAVE ESTIMATES AND SCALARS FOR OUTPUT TABLE

	eststo clear
	foreach out of local outcomes { 
	
		if "`timevar'"=="" {
	

			*Estimation with constant
			qui: regress	  `out' `respvar' `treatvars_minus1'  `intresp'   if `touse' ,  `vce'
			
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
		
		
		if "`timevar'"!="" {
	

			*Estimation with constant
			qui xi: regress	  `out' `respvar' `treatvars_minus1'  `intresp' i.`timevar'  if `touse' ,  `vce'
			
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

	* 6) CALCULATES THE MEAN BASELINE OUTCOME FOR CONTROL ATTRITORS ASSUMING THAT CONTROL GROUP CORRESPOND TO FIRST CATEGORY 
		qui: levelsof  `treatvar', local(treatlevels)
		qui: gettoken    first rest: treatlevels
		qui: sum `out' if `treatvar'==`first' & `respvar'==0
		qui: estadd scalar meanCA=r(mean)

		
	}
			

	* 7) DROP CREATED VARIABLES
		cap:   drop `treatvars' `intresp'   _est*

	
	* 8) PRODUCE OUTPUT TABLE
	  
	  	   if "`vce'"=="" {
			esttab `outcomes' , drop(_cons) cells(b(fmt(3)) se(par fmt(3))) ///
			legend label    nostar            ///
			stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
			addnotes("(+) Mean baseline outcome control attritors")
		   }

	  	  if "`vce'"!="" {
			esttab `outcomes', drop(_cons) cells(b(fmt(3)) se(par fmt(3))) ///
			legend label   nostar             ///
			stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
			addnotes("(+) Mean baseline outcome control attritors" "Standard errors are `vce'")
		   }


		   
	  * 9)  EXPORT OUTPUT TABLE
	  if "`export'"!=""{
	  
	  	   if "`vce'"=="" {
			esttab `outcomes' using "`export'", replace drop(_cons) cells(b( fmt(3)) se(par fmt(3))) ///
			legend label  nostar               ///
			stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
			addnotes("(+) Mean baseline outcome control attritors")
		   }

	  	  if "`vce'"!="" {
			esttab `outcomes' using "`export'", replace drop(_cons) cells(b( fmt(3)) se(par fmt(3))) ///
			legend label    nostar             ///
			stats(meanCA p_IVR p_IVP N, fmt(3 3 3 0) label("Control Attritors(+)" "Test of IV-R (p-val)" "Test of IV-P (p-val)" N)) ///
			addnotes("(+) Mean baseline outcome control attritors" "Standard errors are `vce'")
		   }
	  }

}




if "`stratavar'"!="" {

	* 1) LOCALS WITH NAMES AND VALUES

	*Make sure respvar is a 1/0 variable
    cap:       replace `respvar'=0 if `respvar'!=1 & `respvar'!=.	
	
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
	

	* 2) GENERATE VARIABLES WITH ALL COMBINATIONS OF TREATMENT/RESPONSE/STRATA GROUPS FOR SATURATED MODEL

	* Generate dummy variables for all treatment groups (including control) & store this varlist in  local "treatvars"
	foreach      l in `treatlevels' {
	    gen 	`treatvar'`l'=cond(`treatvar'==`l',1,0) 
		cap: replace  `treatvar'`l'=. if `treatvar'==.
		local    treatvars "`treatvars' `treatvar'`l'"
	}
	
	
	* Generate dummy variables for all strata groups  & store this varlist in  local "stratavars"
	foreach      l in `stratalevels' {
	    gen 	`stratavar'`l'=cond(`stratavar'==`l',1,0) 
		cap: replace  `stratavar'`l'=. if `stratavar'==.
		local    stratavars "`stratavars' `stratavar'`l'"
	}
	
	
	* Group of all dummy variables for treatment groups,  excluding the first category
	gettoken    first rest: treatvars
	local       treatvars_minus1 "`rest'"

	
	* Group of all dummy variables for strata groups,  excluding the first category
	gettoken    first rest: stratavars
	local       stratavars_minus1 "`rest'"


	*Group of interactions: treatment/response
	foreach      g in `treatvars_minus1' {
		gen		 `g'X`respvar'=`g'*`respvar'
		local     int_treatresp "`int_treatresp' `g'X`respvar'"		
	}
	
	
	*Group of interactions: treatment/strata
	foreach      s in `stratavars' {
	foreach      g in `treatvars_minus1' {
		gen		 `g'X`s'=`g'*`s'
		local     int_treatstrata`s' "`int_treatstrata`s'' `g'X`s'"		
	}
		local     int_treatstrata "`int_treatstrata' `int_treatstrata`s'' "		
	}

	
	*Group of interactions: strata/response
	foreach      s in `stratavars' {
		gen		 `respvar'X`s'=`respvar'*`s'
		local     int_respstrata "`int_respstrata' `respvar'X`s'"		
	}

	
	
	
	* Group of interactions:  treatment/respondents/strata
	foreach      s in `stratavars' {
	foreach      g in `treatvars_minus1' {
		gen		 `g'X`respvar'X`s'=`g'*`respvar'*`s'
		local     int_trs`s' "`int_trs`s'' `g'X`respvar'X`s'"		
	}
		local     int_trs "`int_trs' `int_trs`s''"
	}
	
	
	
				
	
	* 3) SAVE NULL HYPOTHESES IN LOCALS : SATURATED MODEL

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


	
	* 4) SAVE NULL HYPOTHESES IN LOCALS: MODEL WITH STRATA FIXED EFFECTS


	*Test of IV-R
	
		local   ivr_vars2 "`treatvars_minus1' `int_treatresp'"
		
		foreach 	v in `ivr_vars2' {
			local   ivr_null2 " `ivr_null2' = `v'"
		}	
		local ivr_null2 "`ivr_null2'=0"
		gettoken   first ivr_null2: ivr_null2, parse(" ")
		

	
	
	*Test of IV-P
		
		local   ivp_vars2 "`treatvars_minus1' `respvar' `int_treatresp'"
		
		foreach 	v in `ivp_vars2' {
			local   ivp_null2 " `ivp_null2' = `v'"
		}	
		local ivp_null2 "`ivp_null2'=0"
		gettoken   first ivp_null2: ivp_null2, parse(" ")


	
	* 5) CONDUCT THE TESTS AND SAVE ESTIMATES AND SCALARS FOR OUTPUT TABLE
	
	cap:  gen `F_IVR'=.
	cap:  gen `p_IVR'=.
	cap:  gen `F_IVR2'=.
	cap:  gen `p_IVR2'=.
	cap:  gen `F_IVP'=.
	cap:  gen `p_IVP'=.
	
	eststo clear
	foreach out of local outcomes { 
	
		if "`timevar'"=="" {	
	
		 *Estimation of fully saturated model
		 qui: regress	  `out' `stratavars' `int_respstrata' `int_treatstrata'   `int_trs'   if `touse' , nocons  `vce'

		
			*Test of IV-R
			qui: test      `ivr_null' 
			qui: replace    `F_IVR'=r(F)
			qui: replace    `p_IVR'=r(p)

			
			*Test of IV-P
			qui: test       `ivp_null'
			qui: replace    `F_IVP'=r(F)
			qui: replace    `p_IVP'=r(p)
			

	
		*Estimation of model with strata fixed effects:IV-R
		 qui: regress	  `out'  `int_respstrata' `treatvars_minus1'  `int_treatresp' `stratavars'  if `touse' ,  nocons `vce'
		
			*Test of IV-R
			qui: test     	`ivr_null2'
			qui: replace    `F_IVR2'=r(F)
			qui: replace    `p_IVR2'=r(p)


		
		*Estimation of model with strata fixed effects:IV-P
		qui: regress	  `out'  `respvar' `treatvars_minus1'  `int_treatresp' `stratavars'  if `touse' ,  nocons `vce'
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
		
		if "`timevar'"!="" {	
	
		 *Estimation of saturated model
		 qui xi: regress	  `out'   `stratavars' `int_respstrata' `int_treatstrata'   `int_trs' i.`timevar' if `touse' , nocons `vce'

		
			*Test of IV-R
			qui: test      `ivr_null' 
			qui: replace    `F_IVR'=r(F)
			qui: replace    `p_IVR'=r(p)

			
			*Test of IV-P
			qui: test       `ivp_null'
			qui: replace    `F_IVP'=r(F)
			qui: replace    `p_IVP'=r(p)
			
		
		*Estimation of model with strata fixed effects: IV-R
		qui: regress	  `out'  `int_respstrata' `treatvars_minus1'  `int_treatresp' `stratavars' i.`timevar'  if `touse' ,  nocons `vce'
		
			*Test of IV-R
			qui: test     	`ivr_null2'
			qui: replace    `F_IVR2'=r(F)
			qui: replace    `p_IVR2'=r(p)


	
		*Estimation of model with strata fixed effects: IV-P
		qui: regress	  `out' `respvar' `treatvars_minus1'  `int_treatresp' `stratavars' i.`timevar'  if `touse' , nocons `vce'
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
	
	
	* 6) CALCULATES THE MEAN BASELINE OUTCOME FOR CONTROL ATTRITORS ASSUMING THAT CONTROL GROUP CORRESPOND TO FIRST CATEGORY 
		qui: levelsof  `treatvar', local(treatlevels)
		qui: gettoken    first rest: treatlevels
		qui: sum `out' if `treatvar'==`first' & `respvar'==0
		qui: estadd scalar meanCA=r(mean)

		
	}
			

	*7) DROP CREATED VARIABLES
		cap:   drop `treatvars' `stratavars' `int_treatresp' `int_treatstrata' `int_respstrata' `int_trs' _est* 
		

	 		
	* 8) PRODUCE OUTPUT TABLE
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
	   
	   
	  * 9) EXPORT OUTPUT TABLE
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
