{smcl}
{* *! version 1.0.0 15Feb2021}{...}
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
{bf:attregtest} {hline 2} implements the regression-based attrition tests proposed in {help attregtest##GHO2020: Ghanem et al. (2020)}.

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:attregtest}
{it:baseline_y1} {it:baseline_y2} {it:baseline_y3} ...
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
{synopt:{opt timevar(varname)}}numerical variable that identifies the different follow-up waves in the field experiment. This option should 
only be used if the goal is to conduct the attrition tests pooling the follow-up waves.{p_end}
{synopt:{opt vce(vcetype)}}{it:vcetype} may be {bf:robust}, {bf:cluster} {it:clustervar}.{p_end}
{synopt:{opt export(filename.format)}} name and format of the file with results that will be exported.{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Notes:{p_end}
{pstd}- {it:baseline_yi} refers to a continuous or binary outcome variable measured at baseline.{p_end}
{pstd}- {it:treatvar} must be a single numerical variable with information on treatment status.
This variable could be either binary or categorical. The reference treatment (or control group) must take the value of zero.{p_end}
{pstd}- {it:respvar} must be a single binary variable that takes the value of 1 for respondents.{p_end}

{marker description}{...}
{title:Description}

{pstd}
{cmd:attregtest} implements the two regression-based attrition tests proposed in {help attregtest##GHO2020: Ghanem et al. (2020)}
for completely or cluster randomized experiments as well as experiments with stratified randomization.  The first test is based on the 
testable implication of the identifying assumption of internal validity for the respondent subpopulation (IV-R). The second test is based on the testable implication
of the identifying assumption of internal validiy for the study population (IV-P).{p_end}

{pstd}
{ul:Completely and cluster randomized experiments:}{p_end}

{pstd} 
If the experiment is completely or cluster randomized and Y_{i0} is the baseline outcome, the null hypotheses of the mean IV-R
and IV-P tests are given by:{p_end}

{p 12 17 2}
Y_{i0}= a + b_{01}R_{i} + b_{10}T_{i} + b_{11}T_{i}R_{i} + e_{i}
{p_end}
{p 12 17 2}
(IV-R)   H_o: b_{10}=b_{11}=0.{p_end}
{p 12 17 2}
(IV-P)   H_o: b_{01}=b_{10}=b_{11}=0.{p_end}

{pstd} 
The null hypothesis of the IV-R test consists of the mean equality of baseline outcome for treatment and control 
respondents as well as treatment and control attritors. The null hypothesis of the IV-P test 
consists of the mean equality of baseline outcome across all treatment/response subgroups.{p_end}

{pstd} 
{cmd:attregtest} uses the command {helpb esttab:[R] {it:esttab}}
to produce an output table with the main regression results and the p-values of the internal validity tests. 
If more than one baseline outcome is specified, the program conducts the test for each baseline outcome separately and 
reports the results for each outcome in a different column. This program does not implement a multiple testing correction.{p_end}

{pstd}
{ul:Stratified randomized experiments:}{p_end}

{pstd} 
If the experiment is stratified, the option {opt stratavar(varname)} must be specified. In this case, the mean sharp testable restrictions of the
IV-R and IV-P assumptions are given by:{p_end}

{p 12 17 2}
Y_{i0}= \Sum_{s=1}^{S}[a^{s} + b_{01}^{s}R_{i} + b_{10}^{s}T_{i} + b_{11}^{s}T_{i}R_{i}]1{S_{i}=s} + e_{i}
{p_end}
{p 12 17 2}
(IV-R)   H_o: b_{10}^{s}=b_{11}^{s}=0 for all s=1,2,...,S.{p_end}
{p 12 17 2}
(IV-P)   H_o: b_{01}^{s}=b_{10}^{s}=b_{11}^{s}=0 for all s=1,2,...,S.{p_end}
 
{pstd} 
The null hypothesis of the IV-R test consists of equality restrictions on the mean baseline outcome for treatment
and control respondents as well as treatment and control attritors {it:within} strata. The null hypothesis of 
the IV-P test consists of equality restrictions on the mean baseline outcome across all treatment/response subgroups {it:within} strata.{p_end}

{pstd}
In addition to testing these null hypotheses, the program for stratified experiments also reports the test results of the following 
implications of the mean sharp testable restrictions:{p_end}

{p 12 17 2}
Y_{i0}= \Sum_{s=1}^{S}[a^{s} +b_{01}^{s}R_{i}]1{S_{i}=s} + b_{10}T_{i} + b_{11}T_{i}R_{i} + e_{i}
{p_end}
{p 12 17 2}
(IV-R)   H_o: b_{10}=b_{11}=0.{p_end}

{p 12 17 2}
Y_{i0}= \Sum_{s=1}^{S}[a^{s}]1{S_{i}=s} + b_{01}R_{i} + b_{10}T_{i} + b_{11}T_{i}R_{i} + e_{i}
{p_end}
{p 12 17 2}
(IV-P)   H_o: b_{01}=b_{10}=b_{11}=0.{p_end}


{pstd} 
Testing these implications can be useful when the number of strata is large, as testing the equality of means across groups {it:within} 
strata may result in high-dimensional inference issues.{p_end}

{pstd} 
{cmd:attregtest} uses the command {helpb esttab:[R] {it:esttab}} to produce an output table with the 
main results of the internal validity tests for the stratified experiments. In this case, the output table reports the coefficients of 
the regression-based test using strata fixed effects only and two sets of p-values. The first set of p-values correspond to the
mean sharp testable restrictions (i.e. fully saturated). The second set, on the other hand, 
correspond to the null hypotheses that test implications of these restrictions (i.e. strata fixed effects only).{p_end}


{pstd} 
For more details on the regression-based tests, see Section B in {help attregtest##GHO2020: Ghanem et al. (2020)}.{p_end} 
 

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
For instance, {cmd:attregtest} {it: baseline_y1} {it: baseline_y2} {it:if} {it:wave}==1, treatvar({it:varname}) respvar({it:varname}).{p_end}


{phang}
{opt vce(vcetype)} specifies the type of standard errors that will be used in the regression-based test. Use ({cmd:robust}) to obtain standard errors
that are robust to heteroskedasticity, and ({cmd:cluster} {it:clustvar}) to obtain cluster-robust standard errors; see {helpb vce_option:[R] {it:vce_option}}.{p_end}


{phang}
{opt export(filename.format)} {cmd:attregtest} uses the command {helpb esttab:[R] {it:esttab}} to produce an output table with the 
main results of the internal validity tests. Use this option if you wish to export this table. The string {it:filename.format} 
specifies the name and the format of the file that will be exported. For instance, {it:testresults.csv} or {it:testresults.tex}. 
The default format is {it:.txt}.
See {helpb esttab:[R] {it:esttab}} for more details on the formats that are supported.{p_end}

{marker examples}{...}
{title:Examples}

{phang}To run these simulated examples you should download the command {helpb randtreat:[R] {it:randtreat}}.{p_end}

{phang}Generate simulated data:

{phang}{stata "clear": . clear}{p_end}
{phang}{stata "set seed 12345": . set seed 12345}{p_end}
{phang}{stata "set obs 1000": . set obs 1000}{p_end}

{phang} Baseline outcomes:{p_end}
{phang}{stata "gen baseline_y1 = 0.2*rnormal()":. gen baseline_y1 = 0.2*rnormal()}{p_end}
{phang}{stata "gen baseline_y2 = 0.5*rnormal()":. gen baseline_y2 = 0.5*rnormal()}{p_end}

{phang} Strata variable:{p_end}
{phang}{stata "gen id = _n":. gen id = _n}{p_end}
{phang}{stata "gen random = runiform()":. gen random = runiform()}{p_end}
{phang}{stata "sort random":. sort random}{p_end}
{phang}{stata "gen sex = _n <= 500":. gen sex = _n <= 500}{p_end}

{phang}Response status:{p_end}
{phang}{stata "gen resp  = (uniform() < .5)": . gen resp  = (uniform() < .5)}{p_end}

{phang}Treatment status:{p_end}
{phang}{stata "randtreat, generate(treat) replace": . randtreat, generate(treat) replace}{p_end}


{phang} 1) Tests of internal validity for single treatment case: completely randomized experiment{p_end}
{phang}{stata "attregtest baseline_y1 baseline_y2, treatvar(treat) respvar(resp)": . attregtest baseline_y1 baseline_y2, treatvar(treat) respvar(resp)}{p_end}

{phang} 2) Tests of internal validity for multiple treatment case: completely randomized experiment{p_end}
{phang}{stata "randtreat, generate(treat) replace mult(4)": . randtreat, generate(treat) replace mult(4)}{p_end}
{phang}{stata "attregtest baseline_y1 baseline_y2, treatvar(treat) respvar(resp)": . attregtest baseline_y1 baseline_y2, treatvar(treat) respvar(resp)}{p_end}

{phang} 3) Tests of internal validity for single treatment case: stratified randomized experiment{p_end}
{phang}{stata "randtreat, generate(treat) replace strata(sex)": . randtreat, generate(treat) replace strata(sex)}{p_end}
{phang}{stata "attregtest baseline_y1 baseline_y2, treatvar(treat) respvar(resp) stratavar(sex)": . attregtest baseline_y1 baseline_y2, treatvar(treat) respvar(resp) stratavar(sex)}{p_end}
 
{marker references}{...}
{title:References}

{marker GHO2020}{...}
{phang}
Ghanem, D., S. Hirshleifer, and K. Ortiz-Becerra. 2020. Testing Attrition Bias in Field Experiments.
{p_end}

{marker authors}{...}
{title:Authors}

{phang}Dalia Ghanem{p_end}
{phang}University of California, Davis{p_end}
{phang}dghanem@ucdavis.edu{p_end}


{phang}Sarojini Hirshleifer{p_end}
{phang}University of California, Riverside{p_end}
{phang}sarojini.hirshleifer@ucr.edu{p_end}


{phang}Karen Ortiz-Becerra{p_end}
{phang}University of California, Davis{p_end}
{phang}kaortizb@ucdavis.edu{p_end}


