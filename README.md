# Benefit-Cost Analysis & Evaluation Model: Universal AI Pipeline (NRT-IPP)

This document describes the current model implemented in `main.R`. The script simulates a benefit-cost analysis for a 20-trainee AI pipeline, calculates discounted net benefits, and reports Net Present Value (NPV) and Social Net Present Value (SNPV) across base, best, and worst cases in constant October 2025 dollars (Real Business Lifecycle).

## 1. Model Purpose & Microeconomic Foundations

The script `main.R` models a structural Benefit-Cost Analysis to simulate a 35-year lifecycle horizon for the program cohorts. It evaluates the net economic impacts on trainees, firms, and societal externalities against a counterfactual "No-Action" baseline.

The analysis is grounded in the microeconomic labor-leisure optimization framework, accounting for behavioral constraints like the backward-bending labor supply curve. Individual satisfaction is modeled using a strictly non-linear logarithmic utility function:

$$U(L,H) = \ln(L) + \ln(C)$$

Where $L$ represents leisure hours ($\ln(L)$ capturing the diminishing marginal utility of income) and $C$ denotes consumption ($\ln(C)$ capturing compounding marginal disutility). 

Welfare transitions are mathematically formalized as:

$$\Delta \text{Welfare Balance} = Y_t \cdot \ln\left(\frac{w_1}{w_0}\right)$$

*Where C = wH = $Y_t$ because gross income is equal to consumption.*

Under real-world conditions, labor market frictions degrade Pareto-efficiency. The model incorporates joint probabilities of unemployment/underemployment $P(E)_c$, annual search penalties $S_t$, and attrition rates $P(A)_c$ to determine realized wages ($w_1$) and deadweight losses ($DWL$):

$$w_1 = w_{\text{target}}(1 - S_t)P(E)_c$$

$$\text{Surplus} = P(A)_c \cdot Y_t \cdot \ln\left(\frac{w_1}{w_0}\right)$$

$$\text{DWL} = P(A)_c \cdot Y_t \cdot \ln\left(\frac{w_{\text{target}}}{w_1}\right)$$

**Example of Work Surplus**

| Affected Group | Old Wage | Target Wage | Surplus |
| --- | --- | --- | --- |
| Code Experts (CE) | $145,906.04 | $150,350 | **$4,377.63** |
| Non-Code Experts | $84,295.86 | $99,234.37 | **$16,190.25** |

*This surplus represents what trainees earn on the Pareto efficiency frontier, capturing both cash premiums and recovered leisure time. May 2022 report from BLS for the CE role is $127,260 that adjusts to $145,906.04 in October 2025. $155,000 in 2026 adjusts to $150,350 in 2025 if 3% inflation rate applies. $79,000 in 2024 from NDC dashboard adjusts to $84,295.86 and $93,000 adjusts to $99,234.37 in October 2025.*

**Example of Work Deficit**

| Affected Group | Old Wage | Target Wage Bundle | Deficit |
| --- | --- | --- | --- |
| Code Experts (CE) | $145,906.04 | $16,000 + $37,000 | **-$147,754.80** |
| Non-Code Experts | $84,295.86 | $16,000 + $37,000 | **-$39,116.72** |

*This deficit measures the welfare contraction trainees are willing to give up for a better long-term alternative if operating under Pareto efficiency.*

## 2. Parameter Ledger

| Parameter | Script Variable | Value | Description |
|:-- |:-- | --:|:-- |
| **CE Target Wage** | `parameter_CE_target_wage` | `$150,350` | Frictionless baseline target income for Coding Experts. |
| **NC Target Wage** | `parameter_NC_target_wage` | `$99,234.37` | Frictionless baseline target income for Non-Coders. |
| **CE Old Wage** | `parameter_CE_old_wage` | `$145,906.04` | Baseline income for Coding Experts before enrollment. |
| **NC Old Wage** | `parameter_NC_old_wage` | `$84,295.86` | Baseline income for Non-Coders before enrollment. |
| **Trainee Stipend** | `parameter_stipend` | `$37,000` | Annual stipend for funded trainees during training years. |
| **Cost of Ed.** | `parameter_COE_wage` | `$16,000` | Institutional cost-of-education funding allocation. |
| **Internship Cost** | `parameter_intern_cost` | `$2,500` | Industry internship overhead per trainee in year 1. |
| **Onboarding NC** | `parameter_onboard_NC` | `$4,700` | Friction adjustment for placing non-coders into entry roles. |
| **Onboarding CE** | `parameter_onboard_CE` | `$6,200` | Friction adjustment for placing specialized coding experts. |
| **Baseline Attrition** | `parameter_attrition_rate` | `23.0%` | Council of Graduate Schools baseline Master's attrition rate. |

## 3. Cohort Structure

The simulated portfolio contains 20 trainees. Trainees are assigned to four types, repeated five times:

| Type | Meaning |
| --- | --- |
| `FT-CE` | Funded trainee, coding expert. |
| `NT-CE` | Non-funded trainee, coding expert. |
| `FT-NC` | Funded trainee, non-coder. |
| `NT-NC` | Non-funded trainee, non-coder. |

If the simulation adjusts to increasing the number of trainees per cohort after the initial cohort, the FT is at 25 maximum while NT is without a limit.

## 4. Time Horizon

The model simulates calendar time from year 0 through year 34:

```r
time_horizon <- 0:34
```

For each trainee, experience time is calculated as:

```r
t_exp = t - t_start
```

Rows are included only when:

* the trainee has already started, and
* `t_exp <= 29`.

This gives each trainee up to 30 observed experience years, from `t_exp = 0` through `t_exp = 29`.

## 5. Post-Graduation Reference Benchmarks

Post-graduation reference boundaries begin at `t_exp >= 2`. To maintain structural validity and align with Search-Matching Theory, `comp_industry` functions as an unreduced Pareto optimal reference:

```r
comp_industry = ifelse(is_CE, CE_target_wage, NC_target_wage)
old_wage      = ifelse(is_CE, CE_old_wage,     NC_old_wage)
```

## 6. Adjusted Work Surplus Under Non-Pareto Efficiency

The worker's realized surplus is scaled downward by search friction (`sear_y`) and labor-market risk (`prob_ris`) to reflect real-world transactional friction:

For the first post-graduation year (`t_exp == 2`):

```r
work_surplus = (comp_industry * (log(comp_industry) - log(old_wage))) * (1 - sear_y_2) * (1 - prob_ris)
```

For all later post-graduation years (`t_exp >= 3`):

```r
work_surplus = (comp_industry * (log(comp_industry) - log(old_wage))) * (1 - sear_y_3) * (1 - prob_ris)
```

*No work surplus is counted during training years (`t_exp <= 1`).*

## 7. Adjusted Work Deficit Under Non-Pareto Efficiency

Funded trainees (`FT-`) experience an opportunity cost deficit during training years (`t_exp <= 1`). The temporary training bundle incorporates institutional funding and utilization variables:

```r
# If FT-NC or FT-CE
COE_Stipend  = (COE_wage * COE_util) + stipend
work_deficit = old_wage * (log(COE_Stipend) - log(old_wage))

# If NT-NC
work_deficit = old_wage * (log(1) - log(old_wage))
```

*For non-funded trainees (`NT-CE`), `work_deficit` equals `0` (their full opportunity cost profile is captured via raw tuition outlays and unearned wage baselines).*

## 8. Industry Productivity and Realized Profit

To properly account for labor market monopsoristic power and wage markdowns without double-counting worker benefits, Marginal Revenue Product (`mrp`) is calculated off the intact Pareto capacity.

The business side harvests the spread between this uncompromised productivity and the actual `realized_wage` handed to the worker after transaction frictions take effect:

```r
# Uncompromised Production Frontier
mrp = comp_industry * (1 + mrp_coef)

# Deflated Wage Handed to Trainee
realized_wage = comp_industry * (1 - sear_y) * (1 - prob_ris)

# Net Remaining Firm Profit
indiv_net_profit = mrp - realized_wage
```

## 9. Deadweight Loss from Friction

The economic value destroyed due to structural barriers, search inefficiencies, and market risk is mathematically captured by measuring the area under the behavioral curve between the optimal benchmark and the deflated wage profile:

```r
deadweight_loss_friction = comp_industry * (log(comp_industry) - log(realized_wage))
```

## 10. Aggregate Costs, Benefits, and Discounting

For each trainee-year row within the tracking matrix, benefits and costs are aggregated as:

```r
costs = tuition_expenditure + deadweight_loss_friction + intern_cost + onboard_cost
benefits = indiv_net_profit + work_surplus + work_deficit
net_benefit = benefits - costs
```

> **Model Reconciliations:**
> 1. `deadweight_loss_friction` scales to `0` for private-level business analysis rows, but applies completely within macroeconomic social calculations.
> 2. `work_deficit` is treated as a component of the `benefits` summation line because its log-integral value evaluates to a negative number, effectively acting as an internal welfare deduction.
> 3. One-time onboarding costs (`onboard_CE` or `onboard_NC`) are parsed explicitly at graduation step `t_exp == 2`.

The engine discounts each timeline instance across the parameter space:

```r
individual_time_npv  = net_benefit / ((1 + privat_r) ^ t)
individual_time_snpv = net_benefit / ((1 + social_r) ^ t)
```

The localized balances compile to yield the final reporting vectors:

```r
total_npv  = sum(individual_time_npv)
total_snpv = sum(individual_time_snpv)

npv  = total_npv
snpv = total_snpv - nsf_award
```

## 10. Scenario Assumptions

The script evaluates three discrete variance profiles:

| Parameter | Base Case | Best Case | Worst Case |
| :-- | --: | --: | --: |
| `social_r` | `0.03` | `0.01` | `0.05` |
| `COE_util` | `0.50` | `0.90` | `0.10` |
| `sear_y_2` | `0.50` | `0.25` | `1.00` |
| `sear_y_3` | `0.05` | `0.01` | `0.09` |
| `prob_ris` | `0.117` | `0.076` | `0.13` |
| `mrp_coef` | `0.70` | `0.75` | `0.65` |

> **Note: in studies, CE may generate 3-to-5 times while NC may generate 1.3-to-1.5 times in term of MRP. But this model intends to be conservative.**

## 11. Expected Script Output

Based on the formulas and parameters in `main.R`, the expected printed results for baseline are:

| Scenario | NPV | SNPV |
| :-- | --: | --: |
| Base Case | `$4,848,254` | `$7,940,638` |
| Best Case | `$11,014,370` | `$23,114,822` |
| Worst Case | ` -$14,271,891` | `-$34,505,195` |

## 12. Implementation Notes

The main function is:

```r
r <- npv_calc_utility(COE_util = 0.50, 
                      sear_y_2 = 0.50, 
                      sear_y_3 = 0.05, 
                      prob_ris = 0.117, 
                      mrp_coef = 0.70,
                      privat_r = 0.07,
                      social_r = 0.03,
                      attrition_rate = parameter_attrition_rate,
                      add_to_each_new_cohort = 0,
                      CE_target_wage=parameter_CE_target_wage,
                      NC_target_wage=parameter_NC_target_wage,
                      CE_old_wage=parameter_CE_old_wage,   
                      NC_old_wage=parameter_NC_old_wage,    
                      stipend=parameter_stipend,        
                      COE_wage=parameter_COE_wage,       
                      intern_cost=parameter_intern_cost,     
                      onboard_NC=parameter_onboard_NC,      
                      onboard_CE=parameter_onboard_CE)
```

It returns a list with:

| Return Field | Description |
| :-- | :-- |
| `data` | Full simulated trainee-year panel. |
| `npv` | Private-rate discounted NPV. |
| `snpv` | Social-rate discounted NPV minus the NSF award. |

The script runs `npv_calc()` once for each scenario and prints the NPV and SNPV values.

If you just want to run this script, copy and paste this in RStudio in **2026_NRT_BCA** folder: `source('main.R')`

If you want to play around with the simulation, run this file: `app.R`

## 13. References

American Psychological Association. (2026). ASPE standard regulatory impact analysis values. U.S. Department of Health and Human Services. https://aspe.hhs.gov/sites/default/files/documents/2d83af5823915d81871334ee08ad03d9/Standard-RIA-Values-2026.pdf

Brynjolfsson, E., & Hitt, L. M. (2003). Computing productivity: Firm-level evidence. The Review of Economics and Statistics, 85(4), 793–808. https://doi.org/10.1162/003465303772815736

Bureau of Labor Statistics. (2022). Software developers (Occupational Employment and Wage Statistics, Code 15-1252). U.S. Department of Labor. https://www.bls.gov/oes/2022/may/oes151252.htm

Bureau of Labor Statistics. (2026). Alternative measures of labor underutilization for states (Local Area Unemployment Statistics). U.S. Department of Labor. https://www.bls.gov/lau/stalt.htm

Fokal. (n.d.). Machine learning engineer salary reference. Fokal AI SEO Research. https://www.fokal.com/ai-seo-research/machine-learning-engineer-salary/

InterviewCost. (n.d.). SHRM cost per hire guide: Technical and engineering sourcing premium metrics. https://interviewcost.com/shrm-cost-per-hire

National Deaf Center on Postsecondary Outcomes. (n.d.). Employment and earnings dashboard: Median earnings by education. https://dashboard.nationaldeafcenter.org/?main=Employment%2FEarnings+by+Education&attr=overall&chart_type=levels&status=Median+Earnings

National Science Foundation. (n.d.). Graduate Research Fellowship Program (GRFP). https://www.nsf.gov/funding/opportunities/grfp-nsf-graduate-research-fellowship-program

Society for Human Resource Management. (n.d.). Recruiting benchmarking: Non-executive talent acquisition baseline. SHRM Research. https://www.shrm.org/topics-tools/research/recruiting-benchmarking

Walton, G. M., Murphy, M. C., Logel, C., Yeager, D. S., Goyer, J. P., Brady, S. T., ... & Krosch, D. J. (2023). A scalable social-belonging intervention to improve academic outcomes. Science, 379(6634), eade4420. https://doi.org/10.1126/science.ade4420

Yeh, C., Macaluso, C., & Hershbein, B. (2022). Monopsony in the U.S. labor market (Upjohn Institute Working Paper No. 22-364). W.E. Upjohn Institute for Employment Research. https://ideas.repec.org/p/upj/weupjo/22-364.html

Hassan, T. A., Kalyani, A., & Restrepo, P. (2026). The skill premium in times of rapid technological change (NBER Working Paper No. 34939). National Bureau of Economic Research. https://doi.org/10.3386/w34939

Bettinger, E. P., & Baker, R. B. (2014). The effects of student coaching: An evaluation of a randomized experiment in student advising. Educational Evaluation and Policy Analysis, 36(1), 3–19. https://doi.org/10.3102/0162373713500523