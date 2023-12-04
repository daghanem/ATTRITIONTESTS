{smcl}
{* *! version 2.0.0 13Nov2023}{...}
{findalias asfradohelp}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] help" "help help"}{...}
{viewerjumpto "Syntax" "examplehelpfile##syntax"}{...}
{viewerjumpto "Description" "examplehelpfile##description"}{...}
{viewerjumpto "Options" "examplehelpfile##options"}{...}
{viewerjumpto "Remarks" "examplehelpfile##remarks"}{...}
{viewerjumpto "Examples" "examplehelpfile##examples"}{...}
{title:Title}

{phang}
{bf:attregtest} {hline 2} implements the regression-based attrition tests proposed in {help attregtest##JHR2023: Ghanem et al. (2023)}. These attrition tests are outcome-specific and can be applied to field experiments with completely, cluster, or stratified randomization. 

{pstd}
This new version of the program allows for the inclusion of additional baseline data on the determinants of (or proxies for) the outcome of interest in the attrition tests. The output of this program is a table with the main regression results and the p-values of the internal validity tests for the outcome in question.{p_end}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:attregtest}
{it: varlist}
{ifin}
{cmd:,}
treatvar(varname)
respvar(varname)
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opt stratavar(varname)}}numerical variable with the strata groups that were used to assign treatment status in the field experiment.{p_end}
{synopt:{opt timevar(varname)}}numerical variable that identifies the different follow-up waves in the field experiment. This option conducts the attrition tests pooling all the follow-up waves.{p_end}
{synopt:{opt vce(vcetype)}}{it:vcetype} may be {bf:robust}, or {bf:cluster} {it:clustervar}.{p_end}
{synopt:{opt export(filename.format)}} name and format of the output table that will be exported.{p_end}
{synoptline}
{p2colreset}{...}


{pstd}NOTES:{p_end}
{pstd}{bf: varlist} refers to the outcome of interest measured at baseline. This varlist can include one or multiple variables depending on whether the researcher chooses to include baseline data on the determinants of (or proxies for) the outcome of interest in the attrition tests as well. See Section IV.B in the paper for a discussion on the proper use of covariates in the attrition tests. {p_end}
{pstd}{bf:treatvar} must be a single numerical variable with information on treatment status. This program can be applied to settings with multiple treatment arms as long as
the reference treatment (or control group) takes the value of zero.{p_end}
{pstd}{bf:respvar} is a binary variable that takes the value of one if the outcome of interest is observed at follow-up.{p_end} 
{pstd}- The command {cmd:attregtest} requires that none of the variables in the dataset is named {it:response}.{p_end}
{pstd}- The command {cmd:attregtest} requires the most updated version of the package {helpb estout:[R] {it:estout}}. You can
update this package using the following code: {it:ssc install estout, replace}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:attregtest} implements the mean version of the two attrition tests proposed in {help attregtest##JHR2023: Ghanem et al. (2023)}. The first test focuses on the testable implication of the identifying assumption of internal validity for the respondent subpopulation (IV-R), and the second test is based on the testable implication
of the identifying assumption of internal validity for the study population (IV-P). For more details on these regression-based tests, see Appendix A in the published version of the paper.  {p_end}

{pstd}
These attrition tests can be applied to completely and cluster randomized experiments as well as experiments with stratified randomization. Here is a brief description of the null hypotheses and the results reported in each case: {p_end}

{pstd}
{ul:Completely and Cluster Randomized Experiments:}{p_end}

{pstd} 
As detailed in Equation 15 in the paper, if the experiment is completely or cluster randomized, the null hypotheses of the mean IV-R
and IV-P tests for the outcome of interest Y_{i0} are given by:{p_end}

{p 12 17 2}
Y_{i0}= a + B_{01}R_{i} + B_{10}T_{i} + B_{11}T_{i}R_{i} + e_{i}
{p_end}
{p 12 17 2}
(IV-R)   H_o: B_{10}=B_{11}=0.{p_end}
{p 12 17 2}
(IV-P)   H_o: B_{01}=B_{10}=B_{11}=0.{p_end}

{pstd} 
where T_{i} denotes treatment status and R_{i} refers to the outcome-specific response status at follow-up. In this case, the null hypothesis of the IV-R test consists of the mean equality of baseline outcome for treatment and control respondents as well as treatment and control attritors. In contrast, the null hypothesis of the IV-P test 
consists of the mean equality of baseline outcome across all treatment/response subgroups.{p_end}

{pstd} 
{it: Adding Covariates to The Test:} If the researcher includes additional baseline data on the determinants of (or proxies for) the outcome of interest in the attrition test, the program conducts the tests proposed in Equation 16 in the paper. These attrition tests are conditions on the joint equality of means across all the specified variables. 
See Section IV.B in the paper for a discussion on the proper use of covariates in the attrition tests.{p_end}


{pstd} 
{it: Reported Output:} In either case, {cmd:attregtest} uses the command {helpb esttab:[R] {it:esttab}}
to produce an output table with the main regression results and the p-values of the internal validity tests. The p-values of the tests are stored in r().{p_end}


{pstd}
{ul:Stratified Randomized Experiments:}{p_end}

{pstd} 
If the experiment is stratified, the mean testable restrictions of the IV-R and IV-P assumptions are conditional versions of the testable restrictions for completely or clustered experiments. Thus, the option {opt stratavar(varname)} must be specified. As described in Equation 18 in the paper, the attrition tests in these settings are given by:{p_end}

{p 12 17 2}
Y_{i0}= \Sum_{s=1}^{S}[a^{s} + B_{01}^{s}R_{i} + B_{10}^{s}T_{i} + B_{11}^{s}T_{i}R_{i}]1{S_{i}=s} + e_{i}
{p_end}
{p 12 17 2}
(IV-R)   H_o: B_{10}^{s}=B_{11}^{s}=0 for all s=1,2,...,S.{p_end}
{p 12 17 2}
(IV-P)   H_o: B_{01}^{s}=B_{10}^{s}=B_{11}^{s}=0 for all s=1,2,...,S.{p_end}
 
{pstd} 
where T_{i} is treatment status, R_{i} is the response status at follow-up, and S is the total number of strata used in the randomization. In this case, the null hypothesis of the IV-R test are equality restrictions on the mean baseline outcome for treatment
and control respondents as well as treatment and control attritors {it:within} each stratum, while the null hypothesis of 
the IV-P test are equality restrictions on the mean baseline outcome across all treatment/response subgroups {it:within} each stratum. {p_end}

{pstd}
Since testing the equality of means {it:within} each stratum may result in high-dimensional inference issues when the number of strata is large, the program also reports the test results of the implications of these restrictions. These implications, detailed in Equation 19 in the paper, are equality restrictions on the mean baseline outcome across subgroups in a model with strata fixed effects: {p_end}

{p 12 17 2}
Y_{i0}= \Sum_{s=1}^{S}[a^{s} +B_{01}^{s}R_{i}]1{S_{i}=s} + B_{10}T_{i} + B_{11}T_{i}R_{i} + e_{i}
{p_end}
{p 12 17 2}
(IV-R)   H_o: B_{10}=B_{11}=0.{p_end}

{p 12 17 2}
Y_{i0}= \Sum_{s=1}^{S}[a^{s}]1{S_{i}=s} + B_{01}R_{i} + B_{10}T_{i} + B_{11}T_{i}R_{i} + e_{i}
{p_end}
{p 12 17 2}
(IV-P)   H_o: B_{01}=B_{10}=B_{11}=0.{p_end}


{pstd} 
{it: Reported Output:} Since the appropriate type of attrition tests for stratified experiments (testable restrictions vs implications) depends on each setting, {cmd:attregtest} produces an output table  with both sets of p-values. The first two p-values correspond to the test of the mean testable restrictions {it: within} each stratum, while the last two p-values correspond to the tests of the implications (i.e., model with strata fixed effects). This table also displays the regression coefficients of the model with strata fixed effects (Equation 19 in the paper), but the fixed effects are omitted for brevity. The p-vals of the testable restrictions are stored as {it: r(pIVR1)} and {it: r(pIVP1)}, while the p-vals of the implications of these restrictions are stored as {it: r(pIVR2)} and {it: r(pIVP2)}.{p_end}

{pstd} 
{it: Adding Covariates to The Test:} If the researcher includes additional baseline data on the determinants of (or proxies for) the outcome of interest in the attrition test, the program tests the joint versions of the testable restrictions and implications described above across all the specified variables in {it: varlist}. 
See Section IV.B in the paper for a discussion on the proper use of covariates in the attrition tests. {p_end}



{marker options}{...}
{title:Options}

{dlgtab:Main}
				 
{phang}
{opt stratavar(varname)} specifies the variable with the strata groups that were used in the field experiment. Variable must be numerical. 
If this option is specified, the program will test the null hypotheses of equality restrictions on the mean baseline
outcome for stratified randomized experiments.{p_end}

{phang}
{opt timevar(varname)} specifies the variable that identifies the different follow-up waves in the field experiment. Variable must be numerical. 
If this option is specified, the program will conduct the attrition tests pooling these follow-up waves.
If the researcher is interested in conducting the test for each follow-up, she should do it separately using the {it:[if]} option. 
For instance, {cmd:attregtest} {it: z1_outcome} {it:if} {it:wave}==1, treatvar({it:varname}) respvar({it:varname}).{p_end}


{phang}
{opt vce(vcetype)} specifies the type of standard errors that will be used in the regression-based test. Use ({cmd:robust}) to obtain standard errors
that are robust to heteroskedasticity, and ({cmd:cluster} {it:clustvar}) to obtain cluster-robust standard errors; see {helpb vce_option:[R] {it:vce_option}}.{p_end}


{phang}
{opt export(filename.format)} {cmd:attregtest} uses the command {helpb esttab:[R] {it:esttab}} to produce an output table with the 
main results of the internal validity tests. Use this option if you wish to export this table. The string {it:filename.format} 
specifies the name and the format of the file that will be exported. For instance, {it:testresults.csv} or {it:testresults.tex}. 
The default format is {it:.txt}.
See {helpb esttab:[R] {it:esttab}} for more details on the supported formats.{p_end}

{marker examples}{...}
{title:Examples}

{phang} This section illustrates how to use the {cmd:attregtest} command to conduct the attrition tests for completely and stratified randomized experiments using a simple example with simulated data. In this simple example, the baseline outcome
(y_b) is determined by two baseline covariates (w_1 and w_2) and a random error, and this random error is assumed to be independent of response status at follow-up.{p_end}

{phang}To run these simulated examples you should download the command {helpb randtreat:[R] {it:randtreat}} using the following code:{it: ssc install randtreat}.{p_end}

{phang}Generate simulated data:

{phang}{stata "clear": . clear}{p_end}
{phang}{stata "set seed 12345": . set seed 12345}{p_end}
{phang}{stata "set obs 1000": . set obs 1000}{p_end}

{phang}Treatment status:{p_end}
{phang}{stata "randtreat, generate(treat) replace": . randtreat, generate(treat) replace}{p_end}

{phang} Baseline covariates that are determinants of the outcome:{p_end}
{phang}{stata "gen w1_b = 0.5*rnormal()":. gen w1_b = 0.5*rnormal()}{p_end}
{phang}{stata "gen w2_b = 0.7*rnormal()":. gen w2_b = 0.7*rnormal()}{p_end}

{phang} Baseline outcome:{p_end}
{phang}{stata "gen y_b = 1 + 0.25*w1_b +  0.25*w2_b + rnormal()":. gen y_b = 1 + 0.25*w1_b +  0.25*w2_b + rnormal()}{p_end}

{phang} Outcome-specific response status at follow-up:{p_end}
{phang}{stata "gen resp_y  = (uniform() < .5)": . gen resp_y  = (uniform() < .5)}{p_end}

{phang} Generate strata variable:{p_end}
{phang}{stata "gen id = _n":. gen id = _n}{p_end}
{phang}{stata "gen random = runiform()":. gen random = runiform()}{p_end}
{phang}{stata "sort random":. sort random}{p_end}
{phang}{stata "gen sex = _n <= 500":. gen sex = _n <= 500}{p_end}


{phang} 1) Tests of internal validity for completely randomized experiment: {p_end}
{phang}{stata "attregtest y_b, treatvar(treat) respvar(resp_y)": . attregtest y_b, treatvar(treat) respvar(resp_y)}{p_end}

{phang} 2) Tests of internal validity for completely randomized experiment, including baseline covariates: {p_end}
{phang}{stata "attregtest y_b w1_b w2_b, treatvar(treat) respvar(resp_y)": . attregtest y_b w1_b w2_b, treatvar(treat) respvar(resp_y)}{p_end}

{phang} 3) Tests of internal validity for stratified randomized experiment: {p_end}
{phang}{stata "randtreat, generate(treat) replace strata(sex)": . randtreat, generate(treat) replace strata(sex)}{p_end}
{phang}{stata "attregtest y_b, treatvar(treat) respvar(resp_y) stratavar(sex)": . attregtest y_b, treatvar(treat) respvar(resp_y) stratavar(sex)}{p_end}

{phang} 4) Tests of internal validity for stratified randomized experiment, including baseline covariates: {p_end}
{phang}{stata "randtreat, generate(treat) replace strata(sex)": . randtreat, generate(treat) replace strata(sex)}{p_end}
{phang}{stata "attregtest y_b  w1_b w2_b, treatvar(treat) respvar(resp_y) stratavar(sex)": . attregtest y_b  w1_b w2_b, treatvar(treat) respvar(resp_y) stratavar(sex)}{p_end}

 
{marker references}{...}
{title:References}

{marker JHR2023}{...}
{phang}
Ghanem, Dalia, Hirshleifer, Sarojini, Ortiz-Becerra, Karen. 2023. Testing Attrition Bias in Field Experiments. {it:Journal of Human Resources}, 
http//doi.org/10.3368/jhr.0920-11190R2.{p_end}

{marker authors}{...}
{title:Authors}

{phang}Dalia Ghanem{p_end}
{phang}University of California, Davis{p_end}
{phang}dghanem@ucdavis.edu{p_end}


{phang}Sarojini Hirshleifer{p_end}
{phang}University of California, Riverside{p_end}
{phang}sarojini.hirshleifer@ucr.edu{p_end}


{phang}Karen Ortiz-Becerra{p_end}
{phang}University of San Diego{p_end}
{phang}kortizbecerra@sandiego.edu{p_end}


