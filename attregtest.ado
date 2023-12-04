*!   attregtest v2.0.0  GHO13Nov2023


program attregtest, rclass 
	version    13
	syntax     varlist(min=1 numeric) [if] [in], treatvar(varlist numeric max=1) respvar(varlist numeric  max=1)  [ vce(passthru) stratavar(varlist numeric max=1) timevar(varlist numeric fv max=1) export(string)] 

	marksample touse, novarlist
	local      res   p_IVP  p_IVR  pIVR1 pIVP1 pIVR2 pIVP2
	tempname   `res' 
	
	
* ##########################
*		WARNINGS
* ##########################
	
	local nbasevars: word count `varlist'
	local nrespvars: word count `respvar'
	
	if  `nrespvars' > 1 {
		display in red "Error: the number of response variables must be equal to one"
		exit
	}
	
	
	qui: count if `treatvar'==0
		if `r(N)'==0 {
			display in red "Error: the control group must take the value of zero"
			exit
		}
		

	qui: count if `respvar'==0
	if `r(N)'==0 {
		display in red "Error: response variable `var' must take the value of zero for attritors"
		exit
	}
	
	
	cap: ds response
	local nwords :  word count `r(varlist)'
		if `nwords'>0 {
			display in red "Error: none of the variables in the dataset can be named response"
			exit
		}

	forvalues i=1/`nbasevars' {
		local varname: word `i' of `varlist'
		qui: count if missing(`varname')
		if  `r(N)' > 0 {
			display in red "Error: none of the variables in `varlist' should have missing values"
		}
	}

* ##########################################
*  COMPLETELY OR CLUSTER RANDOMIZED TRIALS 
* ##########################################

	
if 	"`stratavar'"=="" {	
	
	eststo clear

		
	* =============================
	* LOCALS WITH NAMES AND VALUES
	* =============================
	
	*Store the values of the treatment variable in local "treatlevels"
	qui:	   levelsof  `treatvar', local(treatlevels)

	*Store the G number of treatment groups (including the control group) in local "ngroups"
	local      ngroups: word count `treatlevels'

	*Store name of baseline variables in local "basevars"
	gettoken    first rest: varlist
	local       basevars "`first' `rest'"


	*==================================
	* GENERATE TREATMENT VARIABLES 
	*==================================

	* Generate dummy variables for all treatment groups & store this varlist in  local "treatvars"
	foreach      l in `treatlevels' {
	    qui: gen 	`treatvar'`l'=cond(`treatvar'==`l',1,0) 
		qui: replace  `treatvar'`l'=. if `treatvar'==.
		local    treatvars "`treatvars' `treatvar'`l'"
	}
	
	* Group of all dummy variables for treatment groups,  excluding the first category
	gettoken    first rest: treatvars
	local       treatvars_minus1 "`rest'"

	*============================================================================
	* CONDUCT THE TESTS OF IV-R and IV-P FOR CASE IN WHICH # VARLIST =1 
    *               AND SAVE ESTIMATES FOR OUTPUT TABLE
    *============================================================================

    if `nbasevars' == 1 {

	   eststo clear
	   capture macro drop _treatresp 
		
			
		*------------------------------------------
		* GENERATE TREATMENT/RESPONSE INTERACTIONS
		*-------------------------------------------
		
		* Store list of interactions in local "treatresp"
		qui: gen response=`respvar'
		foreach      g in `treatvars_minus1' {
			gen		 `g'Xresponse=`g'*response
			local     treatresp "`treatresp' `g'Xresponse"
		}
		

		*--------------------------------
		* ESTIMATE REGRESSION MODEL 
		* Note: estimation with constant
		*--------------------------------
		
		*If option timevar is not specified
			
		if "`timevar'"=="" {
			qui: regress	  `basevars'  `treatresp'  `treatvars_minus1' response if `touse' ,  `vce'
			qui: estimates  store model_z1, title("`basevars'")
		}
		
		
		*If option timevar is specified

		if "`timevar'"!="" {
			qui xi: regress	  `basevars' `treatresp' `treatvars_minus1' response i.`timevar'  if `touse' ,  `vce'				
			qui: estimates  store model_z1, title("`basevars'")
		}
		
        *--------------------------------
		*   SET UP NULL HYPOTHESES
		*--------------------------------

        *Set up H0 for IV-R 
		local     ivr_vars "`treatvars_minus1' `treatresp'"
			
		foreach 	v in `ivr_vars' {
			local   ivr_null " `ivr_null' = `v'"
		}	
		local ivr_null "`ivr_null'=0"
		gettoken   first ivr_null: ivr_null, parse(" ")
			
			
		*Set up H0 for IV-P
		local     ivp_vars "`treatvars_minus1' response `treatresp'"
			
		foreach 	v in `ivp_vars' {
			local   ivp_null " `ivp_null' = `v'"
		}	
		local ivp_null "`ivp_null'=0"
		gettoken   first ivp_null: ivp_null, parse(" ")

        *--------------------------------
		*   TEST NULL HYPOTHESES
		*--------------------------------
			
		*Test of IV-R
		qui: test   `ivr_null' 
		qui: estadd scalar    p_IVR=r(p): model_z1
		return scalar p_IVR = r(p)
			
		*Test of IV-P
		qui: test `ivp_null'
		qui: estadd scalar    p_IVP=r(p): model_z1
		return scalar p_IVP = r(p)
		
		*-----------------------------------------------------------------
		* CALCULATES THE MEAN BASELINE VARIABLE FOR CONTROL ATTRITORS 
		* Note: assumes control group corresponds to first category (value=0) 
		*-----------------------------------------------------------------

		qui: levelsof  `treatvar', local(treatlevels)
		qui: gettoken    first rest: treatlevels
		qui: sum `basevars' if `treatvar'==`first' & response==0 & `touse' 
		qui: estadd scalar meanCA=r(mean): model_z1
		return scalar meanCA = r(mean)
		
		
		cap: drop  `treatresp'  response 



    }

    *============================================================================
	* CONDUCT THE TESTS OF IV-R and IV-P FOR CASE IN WHICH # VARLIST > 1 
    *               AND SAVE ESTIMATES FOR OUTPUT TABLE
    *============================================================================

    if `nbasevars' > 1 {

        *-------------------------------------------
        * GENERATE TREATMENT/RESPONSE INTERACTIONS
        *-------------------------------------------
        * Store list of interactions in local "treatresp"
        qui: gen response=`respvar'
        foreach      g in `treatvars_minus1' {
			gen		 `g'Xresponse=`g'*response
			local     treatresp "`treatresp' `g'Xresponse"
		}
        
        
        local i=0
        eststo clear
        foreach var of local basevars { 
            
            local i=`i'+1
            
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            * ESTIMATE REGRESSION WITH `vce' FOR OUTPUT TABLE
            * Note: (i)  estimation with constant
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

            * If option timevar is not specified
        
            if "`timevar'"=="" {
                qui: regress	  `var'  `treatresp'  `treatvars_minus1' response if `touse' ,  `vce'
                qui: estimates  store model_z`i', title("`var'")
            }
    
    
            * If option timevar is specified
            if "`timevar'"!="" {
                qui xi: regress	  `var' `treatresp' `treatvars_minus1' response i.`timevar'  if `touse' ,  `vce'			
                qui: estimates  store model_z`i', title("`var'")
            }


            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            * ESTIMATE REGRESSION MODELS FOR SUEST
            * Notes: (i)  estimation with constant
            *	     (ii) no `vce' here because suest accounts for it
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

            * If option timevar is not specified
        
            if "`timevar'"=="" {
                qui: regress	  `var'  `treatresp'  `treatvars_minus1' response if `touse' 
                qui: estimates  store modelsuest_z`i', title("`var'")
            }
    
    
            * If option timevar is specified
            if "`timevar'"!="" {
                qui xi: regress	  `var' `treatresp' `treatvars_minus1' response i.`timevar'  if `touse' 			
                qui: estimates  store modelsuest_z`i', title("`var'")
            }

            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            *  SET UP NULL HYPOTHESIS IV-R 
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            
        
            * Individual H0
            local     ivr_vars "`treatvars_minus1' `treatresp'"
                            
            foreach 	v in `ivr_vars' {
                local   ivr_null_`i' "`ivr_null_`i'' = [modelsuest_z`i'_mean]`v'"
            }	
            
    
            local ivr_null_`i' "`ivr_null_`i''=0"
            gettoken   first ivr_null_`i': ivr_null_`i', parse(" ")
            local ivr_null_`i' "(`ivr_null_`i'')"
            
            * Joint H0 across all z variables
            local   ivr_null_multz "`ivr_null_multz'  `ivr_null_`i''"
        
    
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            *  SET UP NULL HYPOTHESIS IV-P 
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    
            * Individual H0
        
            local     ivp_vars "`treatvars_minus1' response `treatresp' "
            
            foreach 	v in `ivp_vars' {
                local   ivp_null_`i' " `ivp_null_`i'' = [modelsuest_z`i'_mean]`v'"
            }	
            local ivp_null_`i' "`ivp_null_`i''=0"
            gettoken   first ivp_null_`i': ivp_null_`i', parse(" ")
            local ivp_null_`i' "(`ivp_null_`i'')"

            * Joint H0 across all z variables
            local   ivp_null_multz "`ivp_null_multz'  `ivp_null_`i''"	


            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		    * CALCULATES THE MEAN BASELINE VARIABLE FOR CONTROL ATTRITORS 
		    * Note: assumes control group corresponds to first category (value=0) 
		    *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            qui: levelsof  `treatvar', local(treatlevels)
            qui: gettoken    first rest: treatlevels
            qui: sum `var' if `treatvar'==`first' & response==0 & `touse' 	
            qui: estadd scalar meanCA=r(mean): model_z`i'

        }

        
        *-----------------------------------------------
        * COMBINE ESTIMATION RESTULTS WITH SUEST
        * Note: standard errors are taken care of here
        *-----------------------------------------------

        forvalues i = 1/`nbasevars' {
            local modelsfor_suest " `modelsfor_suest' modelsuest_z`i'"
        }

        qui: suest  `modelsfor_suest'  , `vce'


        *-----------------------------------------------
        * JOINT TESTS OF IV-R AND IV-P
        *-----------------------------------------------

        * Test of IV-R
        qui: test   `ivr_null_multz' 
        qui: estadd scalar    p_IVR=r(p) : model_z`nbasevars'	
		return scalar p_IVR = r(p)
		
        *Test of IV-P
        qui: test `ivp_null_multz'
        qui: estadd scalar    p_IVP=r(p) : model_z`nbasevars'
		return scalar p_IVP = r(p)

        cap: drop  `treatresp'  response 
		

    }


	*========================
	* DROP CREATED VARIABLES
	*========================

	cap:   drop `treatvars'   _est* 

	
	*=======================
	* PRODUCE OUTPUT TABLE
	*=======================
	
    forvalues i = 1/`nbasevars' {
		local modelsz " `modelsz' model_z`i'"
	}

	if `nbasevars' == 1 {
	  	
        if "`vce'"=="" {
            esttab `modelsz' , cells(b(fmt(3)) se(par fmt(3))) ///
            legend label    nostar            ///
            stats(meanCA  N  p_IVR p_IVP , fmt(3 0 3 3) label("Mean value for control attritors" "Observations" "Test of IV-R (p-val)" "Test of IV-P (p-val)" )) ///
            addnotes("The attrition tests correspond to the conditions on the equality of means provided in Eq. (15) in the paper.") ///
			varwidth(32) 
        }

		   
	  	if "`vce'"!="" {
			esttab `modelsz',  cells(b(fmt(3)) se(par fmt(3))) ///
			legend label   nostar             ///
			stats(meanCA N p_IVR p_IVP, fmt(3 0 3 3) label("Mean value for control attritors" "Observations" "Test of IV-R (p-val)" "Test of IV-P (p-val)" )) ///
			addnotes("The attrition tests correspond to the conditions on the equality of means provided in Eq. (15) in the paper." /// 
					"Standard errors are `vce'.")	///
			varwidth(32) 
		}

	}
	  
	  
	if `nbasevars' > 1 {
	  	
	  	if "`vce'"=="" {
			esttab `modelsz' , cells(b(fmt(3)) se(par fmt(3))) ///
			legend label    nostar            ///
			stats(meanCA  N p_IVR p_IVP, fmt(3 0 3 3) label("Mean value for control attritors" "Observations" "Test of IV-R (p-val)" "Test of IV-P (p-val)")) ///
			addnotes("The attrition tests are conditions on the joint equality of means across all baseline variables (see Eq. (16) in the paper).") ///
			varwidth(32) 
		}

		   
	  	if "`vce'"!="" {
			esttab `modelsz',  cells(b(fmt(3)) se(par fmt(3))) ///
			legend label   nostar             ///
			stats(meanCA  N p_IVR p_IVP, fmt(3 0 3 3) label("Mean value for control attritors" "Observations" "Test of IV-R (p-val)" "Test of IV-P (p-val)" )) ///
			addnotes("The attrition tests are conditions on the joint equality of means across all baseline variables (see Eq. (16) in the paper)." ///
					"Standard errors are `vce'.") ///
			varwidth(32) 
		}

	}
	  
	  
  
  
	*=========================
	* EXPORT OUTPUT TABLE
	*=========================
	
	if "`export'"!=""{

        
        if `nbasevars' == 1 {
            
            if "`vce'"=="" {
                esttab `modelsz' using "`export'", cells(b(fmt(3)) se(par fmt(3))) ///
                legend label    nostar            ///
				stats(meanCA  N  p_IVR p_IVP , fmt(3 0 3 3) label("Mean value for control attritors" "Observations" "Test of IV-R (p-val)" "Test of IV-P (p-val)" )) ///
				addnotes("The attrition tests correspond to the conditions on the equality of means provided in Eq. (15) in the paper.") ///
				varwidth(32) 
            }

            
            if "`vce'"!="" {
                esttab `modelsz' using "`export'",  cells(b(fmt(3)) se(par fmt(3))) ///
                legend label   nostar             ///
				stats(meanCA N p_IVR p_IVP, fmt(3 0 3 3) label("Mean value for control attritors" "Observations" "Test of IV-R (p-val)" "Test of IV-P (p-val)" )) ///
				addnotes("The attrition tests  correspond to the conditions on the equality of means provided in Eq. (15) in the paper." /// 
						"Standard errors are `vce'.")	///
				varwidth(32) 
            }

        }
	  
	  
        if `nbasevars' > 1 {
            
            if "`vce'"=="" {
                esttab `modelsz' using "`export'" , cells(b(fmt(3)) se(par fmt(3))) ///
                legend label    nostar            ///
				stats(meanCA  N p_IVR p_IVP, fmt(3 0 3 3) label("Mean value for control attritors" "Observations" "Test of IV-R (p-val)" "Test of IV-P (p-val)")) ///
				addnotes("The attrition tests are conditions on the joint equality of means across all baseline variables (see Eq. (16) in the paper.)") ///
				varwidth(32) 
            }

            
            if "`vce'"!="" {
                esttab `modelsz' using "`export'",  cells(b(fmt(3)) se(par fmt(3))) ///
                legend label   nostar             ///
				stats(meanCA  N p_IVR p_IVP, fmt(3 0 3 3) label("Mean value for control attritors" "Observations" "Test of IV-R (p-val)" "Test of IV-P (p-val)" )) ///
				addnotes("The attrition tests are conditions on the joint equality of means across all baseline variables (see Eq. (16) in the paper.)" ///
						"Standard errors are `vce'.") ///
				varwidth(32) 
				}

        }
    }  
	  
}



* ########################################
*	 STRATIFIED RANDOMIZED TRIALS 
* ########################################


if "`stratavar'"!="" {
	
	eststo clear			

	* ================================
	* LOCALS WITH NAMES AND VALUES
	* ================================

	
	*Store the values of the treatment variable in local "treatlevels"
	qui:	   levelsof  `treatvar', local(treatlevels)
	
	*Store the G number of treatment groups (including the control group) in local "ngroups"
	local      ngroups: word count `treatlevels'
		
	*Store name of baseline variables in local "basevars"
	gettoken    first rest: varlist
	local       basevars "`first' `rest'"
	
	*Store the values of the strata variable in local "stratalevels"
	qui:	   levelsof  `stratavar', local(stratalevels)
	
	*Store S number of strata groups in local nstrata
	local      sgroups: word count `stratalevels'
	
	

	* ===========================================================
	* GENERATE TREATMENT, STRATA, AND TREATMENT STRATA VARIABLES
	* ===========================================================

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

    *============================================================================
	* CONDUCT THE TESTS OF IV-R and IV-P FOR CASE IN WHICH # VARLIST = 1 
    *               AND SAVE ESTIMATES FOR OUTPUT TABLE
    *============================================================================

    if `nbasevars' ==1 {

        *eststo clear			
        capture macro drop _int_treatresp _int_respstrata _int_trs  _ivr_vars _ivr_null _ivp_vars _ivp_null _ivr_vars_fe _ivr_null_fe _ivp_vars_fe _ivp_null_fe
		
		
		*------------------------------------------
		* GENERATE TREATMENT/RESPONSE INTERACTIONS
		*------------------------------------------
		
		*Group of interactions: treatment/response
        qui: gen response=`respvar'

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
		

				
	
		*------------------------------------------------------	
		* SAVE NULL HYPOTHESES IN LOCALS: FULLY SATURATED MODEL
		*------------------------------------------------------

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


	
		*--------------------------------------------------------
		* SAVE NULL HYPOTHESES IN LOCALS: MODEL W STRATA FE ONLY
		*--------------------------------------------------------


		 *Test of IV-R
        
        local   ivr_vars_fe "`treatvars_minus1' `int_treatresp'"
        
        foreach 	v in `ivr_vars_fe' {
            local   ivr_null_fe " `ivr_null_fe' = `v'"
        }	
        local ivr_null_fe "`ivr_null_fe'=0"
        gettoken   first ivr_null_fe: ivr_null_fe, parse(" ")
            

        
        
        *Test of IV-P
        
        local   ivp_vars_fe "`treatvars_minus1' response `int_treatresp'"
        
        foreach 	v in `ivp_vars_fe' {
            local   ivp_null_fe " `ivp_null_fe' = `v'"
        }	
        local ivp_null_fe "`ivp_null_fe'=0"
        gettoken   first ivp_null_fe: ivp_null_fe, parse(" ")


	
		*----------------------------------------------------------------------
		* REGRESSION TESTS 
		* Note: three regressions -- see details in Section B of paper
		*	(1) Strata FE only model: specification for IV-P test
		*	(2) Strata FE only model: specification for IV-R test
        *   (3) Fully saturated model with strata FE and strata-specific coeff
		*----------------------------------------------------------------------
	

            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            * IF OPTION TIMEVAR IS NOT SPECIFIED   
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

		    if "`timevar'"=="" {	
            
            * (1) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-P TEST
			
			    qui: regress	  `basevars'  `int_treatresp' `treatvars_minus1' response `stratavars'  if `touse' ,  nocons `vce'
			    qui: estimates  store model_z1, title("`basevars'")

				*Test of IV-P
				qui: test    `ivp_null_fe'
				qui: estadd scalar    pIVP2=r(p) : model_z1	
				return scalar pIVP2 = `r(p)'
			
		
			* (2) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-R TEST
			    // no need to save estimates b/c output table only reports p-val

			    qui: regress	  `basevars'  `int_respstrata' `treatvars_minus1'  `int_treatresp' `stratavars'  if `touse' ,  nocons `vce'
           

				*Test of IV-R
				qui: test     	`ivr_null_fe'
                qui: estadd scalar    pIVR2=r(p) : model_z1	
				return scalar pIVR2 = `r(p)'

            * (3) ESTIMATION OF FULLY SATURATED MODEL
                // no need to save estimates b/c output table only reports p-val
			 
			    qui: regress	  `basevars' `stratavars' `int_respstrata' `int_treatstrata'   `int_trs'   if `touse' , nocons  `vce'
                

				*Test of IV-R
				qui: test      `ivr_null' 
                qui: estadd scalar    pIVR1=r(p) : model_z1	
				return scalar pIVR1 = r(p)
				
				*Test of IV-P
				qui: test       `ivp_null'
                qui: estadd scalar    pIVP1=r(p) : model_z1	
				return scalar pIVP1= r(p)

			    qui: estadd local modelfe ""
			    qui: estadd local satmodel ""
			
			}
		
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            * IF OPTION TIMEVAR IS SPECIFIED   
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

		    if "`timevar'"!="" {	


            * (1) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-P TEST
			
			    qui xi: regress	  `basevars'  `int_treatresp' `treatvars_minus1' response `stratavars' i.`timevar' if `touse' ,  nocons `vce'
			    qui: estimates  store model_z1, title("`basevars'")

				*Test of IV-P
				qui: test    `ivp_null_fe'
				qui: estadd scalar    pIVP2=r(p) : model_z1	
				return scalar pIVP2 = r(p)
				
	
            * (2) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-R TEST
                // no need to save estimates b/c output table only reports p-val
			 
			    qui xi: regress	  `basevars'  `int_respstrata' `treatvars_minus1'  `int_treatresp' `stratavars' i.`timevar' if `touse' ,  nocons `vce'
                

				*Test of IV-R
				qui: test     	`ivr_null_fe'
                qui: estadd scalar    pIVR2=r(p) : model_z1	
				return scalar pIVR2 = r(p)
			

            * (3) ESTIMATION OF FULLY SATURATED MODEL
                // no need to save estimates b/c output table only reports p-val
			 
			    qui xi: regress	  `basevars' `stratavars' `int_respstrata' `int_treatstrata'   `int_trs' i.`timevar'  if `touse' , nocons  `vce'
                

				*Test of IV-R
				qui: test      `ivr_null' 
                qui: estadd scalar    pIVR1=r(p) : model_z1	
				return scalar pIVR1 = r(p)
				
				*Test of IV-P
				qui: test       `ivp_null'
                qui: estadd scalar    pIVP1=r(p) : model_z1	
				return scalar pIVP1 = r(p)

			    qui: estadd local modelfe ""
			    qui: estadd local satmodel ""

		    }
	
	
		* -------------------------------------------------------------------
		* CALCULATES THE MEAN BASELINE VARIABLE FOR CONTROL ATTRITORS 
		* Note: assumes control group corresponds to first category (value=0) 
		*--------------------------------------------------------------------
		qui: levelsof  `treatvar', local(treatlevels)
		qui: gettoken    first rest: treatlevels
		qui: sum `basevars' if `treatvar'==`first' & response==0 & `touse'
		qui: estadd scalar meanCA=r(mean): model_z1
		return scalar meanCA = r(mean)
		
	    cap:   drop  `int_treatresp' `int_respstrata' `int_trs' response
	
	}


    *============================================================================
	* CONDUCT THE TESTS OF IV-R and IV-P FOR CASE IN WHICH # VARLIST > 1 
    *               AND SAVE ESTIMATES FOR OUTPUT TABLE
    *============================================================================

    if `nbasevars' > 1 {
	
	    
	    eststo clear
        capture macro drop _int_treatresp _int_respstrata _int_trs  _ivr_vars _ivr_null _ivp_vars _ivp_null _ivr_vars_fe _ivr_null_fe _ivp_vars_fe _ivp_null_fe


        *------------------------------------------
		* GENERATE TREATMENT/RESPONSE INTERACTIONS
		*------------------------------------------
		
        qui: gen response=`respvar'

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

        
        local i=0    
	    foreach var of local basevars { 
	
			local i=`i'+1
			
	        *------------------------------------------------------
            * SAVE NULL HYPOTHESES IN LOCALS: FULLY STURATED MODEL
            *------------------------------------------------------
                *~~~~~~~~~~~~~~~~~
                *   TEST OF IV-R
                *~~~~~~~~~~~~~~~~
            
                * Individual H0
                local   ivr_vars "`int_treatstrata' `int_trs'"
                
                foreach 	v in `ivr_vars' {
                    local   ivr_null_`i' " `ivr_null_`i'' = [mfull_z`i'_mean]`v'"
                }	
                local ivr_null_`i' "`ivr_null_`i''=0"
                gettoken   first ivr_null_`i': ivr_null_`i', parse(" ")
                local ivr_null_`i' "(`ivr_null_`i'')"
            
                * Joint H0 across all z variables
                local   ivr_null_multz_full "`ivr_null_multz_full'  `ivr_null_`i''"
                

                *~~~~~~~~~~~~~~~~~
                *   TEST OF IV-P
                *~~~~~~~~~~~~~~~~
           
                * Individual H0
                local   ivp_vars " `int_treatstrata' `int_respstrata' `int_trs'"
                
                foreach 	v in `ivp_vars' {
                    local   ivp_null_`i' " `ivp_null_`i'' = [mfull_z`i'_mean]`v'"
                 }	
                local ivp_null_`i' "`ivp_null_`i''=0"
                gettoken   first ivp_null_`i': ivp_null_`i', parse(" ")
                local ivp_null_`i' "(`ivp_null_`i'')"

                * Joint H0 across all z variables
                local   ivp_null_multz_full "`ivp_null_multz_full'  `ivp_null_`i''"	
           
	
            *---------------------------------------------------------
            * SAVE NULL HYPOTHESES IN LOCALS: MODEL W STRATA FE ONLY
            *---------------------------------------------------------


                *~~~~~~~~~~~~~~~~~
                *   TEST OF IV-R
                *~~~~~~~~~~~~~~~~
        
                * Individual H0
                local   ivr_vars_fe "`treatvars_minus1' `int_treatresp'"
                
                foreach 	v in `ivr_vars_fe' {
                    local   ivr_null_fe_`i' " `ivr_null_fe_`i'' = [mfeivr_z`i'_mean]`v'"
                }	
                local ivr_null_fe_`i' "`ivr_null_fe_`i''=0"
                gettoken   first ivr_null_fe_`i': ivr_null_fe_`i', parse(" ")
                local ivr_null_fe_`i' "(`ivr_null_fe_`i'')"

                * Joint H0 across all z variables
                local   ivr_null_multz_fe "`ivr_null_multz_fe'  `ivr_null_fe_`i''"



                *~~~~~~~~~~~~~~~~~
                *   TEST OF IV-P
                *~~~~~~~~~~~~~~~~
        
                * Individual H0
                
                local   ivp_vars_fe "`treatvars_minus1' response `int_treatresp'"
                
                foreach 	v in `ivp_vars_fe' {
                    local   ivp_null_fe_`i' " `ivp_null_fe_`i'' = [mfeivp_z`i'_mean]`v'"
                }	


                local ivp_null_fe_`i' "`ivp_null_fe_`i''=0"

                gettoken   first ivp_null_fe_`i': ivp_null_fe_`i', parse(" ")
                local ivp_null_fe_`i' "(`ivp_null_fe_`i'')"

                * Joint H0 across all z variables
                local   ivp_null_multz_fe "`ivp_null_multz_fe'  `ivp_null_fe_`i''"


            *--------------------------------------------------------------------
            * REGRESSION TESTS 
            * Note: three regressions -- see details in Section B of paper
            * (1) Strata FE only model: specification for IV-P test
		    * (2) Strata FE only model: specification for IV-R test
            * (3) Fully saturated model with strata FE and strata-specific coeff
            *--------------------------------------------------------------------

                *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                * IF OPTION TIMEVAR IS NOT SPECIFIED
                *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                if "`timevar'"=="" {	
                
                * (1) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-P TEST
                    //estimates and pvals are reported in output table
                
                    *Using `vce'
                    qui: regress	  `var'  `int_treatresp' `treatvars_minus1' response `stratavars'  if `touse' ,  nocons `vce'
                    qui: estimates  store model_z`i', title("`var'")

                    * Without `vce' for suest
                    qui: regress	  `var'  `int_treatresp' `treatvars_minus1' response `stratavars'  if `touse' ,  nocons 
                    qui: estimates  store mfeivp_z`i', title("`var'")

                * (2) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-R TEST 
                    // only pvals are repoted in output table
                    
                    *Without `vce' for suest
                    qui: regress	  `var'  `int_respstrata' `treatvars_minus1'  `int_treatresp' `stratavars'  if `touse' ,  nocons 
                    qui: estimates  store mfeivr_z`i', title("`var'")

                * (3) ESTIMATION OF FULLY SATURATED MODEL: 
                   // only pvals are repoted in output table
                    
                    * Without `vce' for suest
                    qui: regress	  `var' `stratavars' `int_respstrata' `int_treatstrata'   `int_trs'   if `touse' , nocons  
                    qui: estimates  store mfull_z`i', title("`var'")  


                qui: estadd local modelfe ""
                qui: estadd local satmodel ""
                
                }

                *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                * IF OPTION TIMEVAR IS SPECIFIED
                *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                if "`timevar'"!="" {	

                 * (1) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-P TEST
                    //estimates and pvals are reported in output table
                
                    *Using `vce'
                    qui xi:: regress	  `var'  `int_treatresp' `treatvars_minus1' response `stratavars'  i.`timevar'  if `touse' ,  nocons `vce'
                    qui: estimates  store model_z`i', title("`var'")

                    * Without `vce' for suest
                    qui xi:: regress	  `var'  `int_treatresp' `treatvars_minus1' response `stratavars'  i.`timevar' if `touse' ,  nocons 
                    qui: estimates  store mfeivp_z`i', title("`var'")

                * (2) ESTIMATION OF STRATA FE ONLY MODEL: SPECIFICATION OF IV-R TEST 
                    // only pvals are repoted in output table
                    
                    *Without `vce' for suest
                    qui xi:: regress	  `var'  `int_respstrata' `treatvars_minus1'  `int_treatresp' `stratavars'  i.`timevar'  if `touse' ,  nocons 
                    qui: estimates  store mfeivr_z`i', title("`var'")

                * (3) ESTIMATION OF FULLY SATURATED MODEL: 
                   // only pvals are repoted in output table
                    
                    * Without `vce' for suest
                    qui xi:: regress	  `var' `stratavars' `int_respstrata' `int_treatstrata'   `int_trs'  i.`timevar'   if `touse' , nocons  
                    qui: estimates  store mfull_z`i', title("`var'")  


                qui: estadd local modelfe ""
                qui: estadd local satmodel ""
                                
                }
            
	
	
		    *---------------------------------------------------------------------
		    * CALCULATES THE MEAN BASELINE VARIABLE FOR CONTROL ATTRITORS 
		    * Note: assumes control group corresponds to first category (value=0) 
		    *---------------------------------------------------------------------
		    qui: levelsof  `treatvar', local(treatlevels)
		    qui: gettoken    first rest: treatlevels
		    qui: sum `var' if `treatvar'==`first' & response==0 & `touse' 
		    qui: estadd scalar meanCA=r(mean): model_z`i'

	       
	
	    }

        *-----------------------------------------------
        * COMBINE ESTIMATION RESTULTS WITH SUEST & 
        *       TEST HYPOTHESES
        * Note: standard errors are taken care of here
        *-----------------------------------------------
            
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            *   MODELS WITH STRATA FE - IVP SPECIFICATION
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        
            * Combine fully saturated models 
            forvalues i = 1/`nbasevars' {
                local modelsfe_suest_ivp " `modelsfe_suest_ivp' mfeivp_z`i'"
            }

            qui: suest  `modelsfe_suest_ivp'  , `vce'
            
            *Test of IV-P
            qui: test `ivp_null_multz_fe'
            qui: estadd scalar    pIVP2=r(p) : model_z`nbasevars'
			return scalar pIVP2= r(p)


            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            *   MODELS WITH STRATA FE - IVR SPECIFICATION
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        
            * Combine fully saturated models
            forvalues i = 1/`nbasevars' {
                local modelsfe_suest_ivr " `modelsfe_suest_ivr' mfeivr_z`i'"
            }

            qui: suest  `modelsfe_suest_ivr'  , `vce'

            * Test of IV-R
            qui: test   `ivr_null_multz_fe'
            qui: estadd scalar    pIVR2=r(p) : model_z`nbasevars'	
			return scalar pIVR2= r(p)


            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            *   FULLY SATURATED MODELS
            *~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        
            * Combine fully saturated models
            forvalues i = 1/`nbasevars' {
                local modelsfull_suest " `modelsfull_suest' mfull_z`i'"
            }

            qui: suest  `modelsfull_suest'  , `vce'

            * Test of IV-R
            qui: test   `ivr_null_multz_full'
            qui: estadd scalar    pIVR1=r(p) : model_z`nbasevars'	
            return scalar pIVR1= r(p)
			
            *Test of IV-P
            qui: test `ivp_null_multz_full'
            qui: estadd scalar    pIVP1=r(p) : model_z`nbasevars'
			return scalar pIVP1= r(p)

        cap:   drop  `int_treatresp' `int_respstrata' `int_trs' response

    }


	*========================
	* DROP CREATED VARIABLES
	*========================
		cap:   drop `treatvars' `stratavars' `int_treatstrata'  _est* 
		

	 	
	*=======================
	* PRODUCE OUTPUT TABLE
	*=======================

    forvalues i = 1/`nbasevars' {
		local modelsz " `modelsz' model_z`i'"
	}


    if `nbasevars' == 1 {
        if "`vce'"=="" {
            esttab `modelsz', cells(b(fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
            legend label   nostar              ///
            stats(meanCA N  satmodel  pIVR1 pIVP1 modelfe pIVR2 pIVP2, fmt(3 0 0 3 3 0 3 3 ) ///
            label("Mean value for control attritors" "Observations"   "TESTABLE RESTRICTIONS(+)"  "Test of IV-R (p-val)" "Test of IV-P (p-val)"  "IMPLICATIONS OF RESTR.(&)" ///
			"Test of IV-R (p-val)" "Test of IV-P (p-val)")) ///
            addnotes("(+)These tests are conditions on the equality of means within strata (see Eq. 18 in the paper)." ///
			"(&)These tests are conditions on the equality of means in the model with strata fixed effects (see Eq. 19 in the paper)." ///
			"The reported coefficients correspond to the model in Eq. 19 in the paper." ) ///
			varwidth(32)
        }
        
        if "`vce'"!="" {
            esttab `modelsz', cells(b( fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
            legend label   nostar              ///
            stats(meanCA N  satmodel  pIVR1 pIVP1 modelfe pIVR2 pIVP2, fmt(3 0 0 3 3 0 3 3 ) ///
            label("Mean value for control attritors" "Observations"   "TESTABLE RESTRICTIONS(+)"  "Test of IV-R (p-val)" "Test of IV-P (p-val)"  "IMPLICATIONS OF RESTR.(&)" ///
			"Test of IV-R (p-val)" "Test of IV-P (p-val)")) ///
            addnotes("(+)These tests are conditions on the equality of means within strata (see Eq. 18 in the paper)." ///
			"(&)These tests are conditions on the equality of means in the model with strata fixed effects (see Eq. 19 in the paper)." ///
			"The reported coefficients correspond to the model in Eq. 19 in the paper." ///
			"Standard errors are `vce'") ///
			varwidth(32)
        }
    }


    if `nbasevars' > 1 {
        if "`vce'"=="" {
            esttab `modelsz', cells(b(fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
            legend label   nostar              ///
            stats(meanCA N  satmodel  pIVR1 pIVP1 modelfe pIVR2 pIVP2, fmt(3 0 0 3 3 0 3 3 ) ///
            label("Mean value for control attritors" "Observations"   "TESTABLE RESTRICTIONS(+)"  "Test of IV-R (p-val)" "Test of IV-P (p-val)"  "IMPLICATIONS OF RESTR.(&)" ///
			"Test of IV-R (p-val)" "Test of IV-P (p-val)")) ///
			addnotes("The attrition tests are conditions on the joint equality of means across all baseline variables." ///
			"(+)These tests are conditions on the equality of means within strata." ///
			"(&)These tests are conditions on the equality of means in a model with strata fixed effects." ///
			"The reported coefficients correspond to the model in Eq. 19 in the paper." ) ///
            varwidth(32)       
        }
        
        if "`vce'"!="" {
            esttab `modelsz', cells(b( fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
            legend label   nostar              ///
            stats(meanCA N  satmodel  pIVR1 pIVP1 modelfe pIVR2 pIVP2, fmt(3 0 0 3 3 0 3 3 ) ///
            label("Mean value for control attritors" "Observations"   "TESTABLE RESTRICTIONS(+)"  "Test of IV-R (p-val)" "Test of IV-P (p-val)"  "IMPLICATIONS OF RESTR.(&)" ///
			"Test of IV-R (p-val)" "Test of IV-P (p-val)")) ///
			addnotes("The attrition tests are conditions on the joint equality of means across all baseline variables." ///
			"(+)These tests are conditions on the equality of means within strata." ///
			"(&)These tests are conditions on the equality of means in a model with strata fixed effects." ///
			"The reported coefficients correspond to the model in Eq. 19 in the paper."  ///
			"Standard errors are `vce'" )  ///
			varwidth(32)  
        }
    }
	   
	   
	*========================
	* EXPORT OUTPUT TABLE
	*========================
	
	if "`export'"!=""{

        if `nbasevars' == 1 {
            if "`vce'"=="" {
                esttab `modelsz' using "`export'", cells(b(fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
                legend label   nostar              ///
				stats(meanCA N  satmodel  pIVR1 pIVP1 modelfe pIVR2 pIVP2, fmt(3 0 0 3 3 0 3 3 ) ///
				label("Mean value for control attritors" "Observations"   "TESTABLE RESTRICTIONS(+)"  "Test of IV-R (p-val)" "Test of IV-P (p-val)"  "IMPLICATIONS OF RESTR.(&)" ///
				"Test of IV-R (p-val)" "Test of IV-P (p-val)")) ///
				addnotes("(+)These tests are conditions on the equality of means within strata (see Eq. 18 in the paper)." ///
				"(&)These tests are conditions on the equality of means in the model with strata fixed effects (see Eq. 19 in the paper)." ///
				"The reported coefficients correspond to the model in Eq. 19 in the paper." ) ///
				varwidth(37)
            }
            
            if "`vce'"!="" {
                esttab `modelsz' using "`export'", cells(b( fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
                legend label   nostar              ///
				stats(meanCA N  satmodel  pIVR1 pIVP1 modelfe pIVR2 pIVP2, fmt(3 0 0 3 3 0 3 3 ) ///
				label("Mean value for control attritors" "Observations"   "TESTABLE RESTRICTIONS(+)"  "Test of IV-R (p-val)" "Test of IV-P (p-val)"  "IMPLICATIONS OF RESTR.(&)" ///
				"Test of IV-R (p-val)" "Test of IV-P (p-val)")) ///
				addnotes("(+)These tests are conditions on the equality of means within strata (see Eq. 18 in the paper)." ///
				"(&)These tests are conditions on the equality of means in the model with strata fixed effects (see Eq. 19 in the paper)." ///
				"The reported coefficients correspond to the model in Eq. 19 in the paper."  ///
				"Standard errors are `vce'") ///
				varwidth(32)
            }
        }


        if `nbasevars' > 1 {
            if "`vce'"=="" {
                esttab `modelsz' using "`export'", cells(b(fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
                legend label   nostar              ///
				stats(meanCA N  satmodel  pIVR1 pIVP1 modelfe pIVR2 pIVP2, fmt(3 0 0 3 3 0 3 3 ) ///
				label("Mean value for control attritors" "Observations"   "TESTABLE RESTRICTIONS(+)"  "Test of IV-R (p-val)" "Test of IV-P (p-val)"  "IMPLICATIONS OF RESTR.(&)" ///
				"Test of IV-R (p-val)" "Test of IV-P (p-val)")) ///
				addnotes("The attrition tests are conditions on the joint equality of means across all baseline variables." ///
				"(+)These tests are conditions on the equality of means within strata." ///
				"(&)These tests are conditions on the equality of means in a model with strata fixed effects." ///
				"The reported coefficients correspond to the model in Eq. 19 in the paper." ) ///
				varwidth(32)       
            }
            
            if "`vce'"!="" {
                esttab `modelsz' using "`export'", cells(b( fmt(3)) se(par fmt(3))) drop(`stratavars' ) ///
                legend label   nostar              ///
				stats(meanCA N  satmodel  pIVR1 pIVP1 modelfe pIVR2 pIVP2, fmt(3 0 0 3 3 0 3 3 ) ///
				label("Mean value for control attritors" "Observations"   "TESTABLE RESTRICTIONS(+)"  "Test of IV-R (p-val)" "Test of IV-P (p-val)"  "IMPLICATIONS OF RESTR.(&)" ///
				"Test of IV-R (p-val)" "Test of IV-P (p-val)")) ///
				addnotes("The attrition tests are conditions on the joint equality of means across all baseline variables." ///
				"(+)These tests are conditions on the equality of means within strata." ///
				"(&)These tests are conditions on the equality of means in a model with strata fixed effects." ///
				"The reported coefficients correspond to the model in Eq. 19 in the paper."  ///
				"Standard errors are `vce'" )  ///
				varwidth(37)  
            }
        }
    }
}

end
