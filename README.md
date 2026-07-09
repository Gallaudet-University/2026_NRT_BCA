# Benefit-Cost Analysis Model

This document describes the current model implemented in `main.R`. The script simulates a benefit-cost analysis for a 20-trainee AI pipeline, calculates discounted net benefits, and reports Net Present Value (NPV) and Social Net Present Value (SNPV) across base, best, and worst cases in constant October 2025 dollars (Real Business Lifecycle).

## 1. Model Purpose

The script estimates the discounted economic value of the pipeline under a counterfactual program structure. It combines trainee-level wage premiums, education support, opportunity costs, tuition costs, industry productivity, internship costs, and labor-market frictions.

Two aggregate metrics are produced:

* **NPV:** Total discounted net benefit using the private discount rate.
* **SNPV:** Total discounted net benefit using the social discount rate, minus the NSF award.

The NSF award is undiscounted due to the initial year of this program and treated as a cost in the SNPV:

```r
snpv = total_snpv - nsf_award
```

## 2. Fixed Parameters

##### The Structural Derivation

Let a worker have a classic Stone-Geary or logarithmic utility function over consumption ($C$) and labor hours ($H$), given a total time endowment $T$:

$$U(C, H) = \ln(C) - \psi(H)$$

Where $\psi(H)$ is the convex disutility of work.

##### 1. The Budget Constraint and "Target Earning"

The worker faces the budget constraint $C = wH + I$, where $w$ is the hourly wage rate and $I$ is unearned baseline income.

Under this behavioral framework, workers optimize up until a reference earnings target $\bar{Y} = wH$, at which point the marginal disutility of labor $\psi'(H)$ becomes effectively infinite (a hard kink in preferences). Thus, in the neighborhood of the target:

* $H \approx \bar{H}$ (hours are locally inelastic).
* Total Earned Income is fixed at $\bar{Y} = w\bar{H}$.

##### 2. Defining Welfare via Money-Metric Utility

Welfare changes in econometrics are evaluated using the Indirect Utility Function $V(w, I)$. The compensating variation ($CV$) for a wage change from a baseline $w_0$ (Lower Income Baseline) to $w_1$ (Higher Wage Baseline) is implicitly defined by:

$$V(w_1, I - CV) = V(w_0, I)$$

Using our structural utility function under the localized target-earning assumption ($H = \bar{H}$):

$$\ln(w_1\bar{H} + I - CV) - \psi(\bar{H}) = \ln(w_0\bar{H} + I) - \psi(\bar{H})$$

The disutility of labor $\psi(\bar{H})$ cancels out across states because hours are fixed by the target:

$$\ln(w_1\bar{H} + I - CV) = \ln(w_0\bar{H} + I)$$

##### 3. First-Order Taylor Approximation

To see where your exact log-difference formula originates, we take a first-order Taylor expansion of the utility change $\Delta U$ with respect to the income baselines ($Y_1 = w_1\bar{H} + I$ and $Y_0 = w_0\bar{H} + I$).

The marginal utility of income is defined as:

$$\lambda = \frac{\partial U}{\partial Y} = \frac{1}{Y}$$

By the Mean Value Theorem, the change in utility between the two states can be written as:

$$\Delta U = \ln(Y_1) - \ln(Y_0)$$

To convert this utility change back into monetary terms (the Welfare Balance, or $CV$), econometric theory mandates dividing the utility difference by the marginal utility of wealth evaluated at the baseline, $\lambda_0 = \frac{1}{Y_0}$:

$$\text{Welfare Balance (in \$)} \approx \frac{\Delta U}{\lambda_0} = \frac{\ln(Y_1) - \ln(Y_0)}{1/Y_0} = Y_0 \left[ \ln(Y_1) - \ln(Y_0) \right]$$

##### 4. Reconciling with Your Variables

If we assume that unearned income $I = 0$, then the baseline total income is exactly equal to the reference target earning ($Y_0 = w_0\bar{H} = \text{Target Earning}$).

Therefore:

> **General Microeconomic Foundation:** > Welfare Balance = Target Earning $\times$ ($\ln$(Higher Wage Baseline) $-$ $\ln$(Lower Income Baseline))

### 2.1 Work Surplus (Post-Graduation Years 2–29)

| Affected Group | Old Wage | Target Wage | Surplus |
| --- | --- | --- | --- |
| Code Experts (CE) | $145,906.04 | $150,350 | **$9,743.21** |
| Non-Code Experts | $84,295.86 | $99,234.37 | **$16,190.25** |

*This surplus represents what trainees earn on the Pareto efficiency frontier, capturing both cash premiums and recovered leisure time. May 2022 report from BLS for the CE role is $127,260 that adjusts to $145,906.04 in October 2025. $155,000 in 2026 adjusts to $150,350 in 2025 if 3% inflation rate applies. $79,000 in 2024 from NDC dashboard adjusts to $84,295.86 and $93,000 adjusts to $99,234.37 in October 2025.*

### 2.2 Opportunity Cost Deficit (Training Years 0–1)

| Affected Group | Old Wage | Target Wage Bundle | Deficit |
| --- | --- | --- | --- |
| Code Experts (CE) | $145,906.04 | $16,000 + $37,000 | **-$147,754.80** |
| Non-Code Experts | $84,295.86 | $16,000 + $37,000 | **-$39,116.72** |

*This deficit measures the welfare contraction trainees are willing to give up for a better long-term alternative if operating under Pareto efficiency.*

### 2.3 Parameter Ledger

| Parameter | Value | Description |
| --- | --- | --- |
| `CE_target_wage` | `$155,000` | Target income CE is willing to give up to get (Frictionless baseline). |
| `NC_target_wage` | `$93,000` | Target income NC is willing to give up to get (Frictionless baseline). |
| `CE_old_wage` | `$127,260` | The old income CE had before enrollment. |
| `NC_old_wage` | `$79,000` | The old income NC had before enrollment. |
| `stipend` | `$37,000` | Annual stipend for funded trainees during training years. |
| `COE_wage` | `$16,000` | Annual cost-of-education allocation used for funded trainees. |
| `nsf_award` | `$4,500,000` | NSF award deducted from social NPV. |
| `tuition` | `$21,168` | Annual tuition cost for non-funded trainees during training years. |
| `intern_cost` | `$2,500` | Industry internship cost applied in trainee experience year 1. |
| `onboard_NC` | `$4,700` | One-time recruitment friction applied in experience year 2 for non-coders. |
| `onboard_CE` | `$6,200` | One-time specialized onboarding friction applied in experience year 2 for coding experts. |

## 3. Cohort Structure

The simulated portfolio contains 20 trainees. Trainees are assigned to four types, repeated five times:

| Type | Meaning |
| --- | --- |
| `FT-CE` | Funded trainee, coding expert. |
| `NT-CE` | Non-funded trainee, coding expert. |
| `FT-NC` | Funded trainee, non-coder. |
| `NT-NC` | Non-funded trainee, non-coder. |

The four trainee types enter as one batch per start year. The `t_start` value is calculated as:

```r
t_start = (0:19) %/% 4
```

This creates five entry batches, with four trainees starting in each of years 0, 1, 2, 3, and 4.

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

## 5. Trainee-Level Calculations

### 5.1 Tuition Expenditure

Non-funded non-coder trainees pay $21,168 tuition during training years. This applies when:

* trainee type contains `NT-NC`, and
* `t_exp <= 1`.

### 5.2 Post-Graduation Reference Benchmarks

Post-graduation reference boundaries begin at `t_exp >= 2`. To maintain structural validity and align with Search-Matching Theory, `comp_industry` functions as an unreduced Pareto optimal reference:

```r
comp_industry = ifelse(is_CE, CE_target_wage, NC_target_wage)
old_wage      = ifelse(is_CE, CE_old_wage,     NC_old_wage)
```

### 5.3 Adjusted Work Surplus Under Non-Pareto Efficiency

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

### 5.4 Adjusted Work Deficit Under Non-Pareto Efficiency

Funded trainees (`FT-`) experience an opportunity cost deficit during training years (`t_exp <= 1`). The temporary training bundle incorporates institutional funding and utilization variables:

```r
COE_Stipend  = (COE_wage * COE_util) + stipend
work_deficit = old_wage * (log(COE_Stipend) - log(old_wage))
```

*For non-funded trainees (`NT-CE`), `work_deficit` equals `0` (their full opportunity cost profile is captured via raw tuition outlays and unearned wage baselines).*

### 5.5 Industry Productivity and Realized Profit

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

### 5.6 Deadweight Loss from Friction

The economic value destroyed due to structural barriers, search inefficiencies, and market risk is mathematically captured by measuring the area under the behavioral curve between the optimal benchmark and the deflated wage profile:

```r
deadweight_loss_friction = comp_industry * (log(comp_industry) - log(realized_wage))
```

## 6. Aggregate Costs, Benefits, and Discounting

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

## 7. Scenario Assumptions

The script evaluates three discrete variance profiles:

| Parameter | Base Case | Best Case | Worst Case |
| --- | --- | --- | --- |
| `COE_util` | `0.50` | `0.90` | `0.10` |
| `sear_y_2` | `0.50` | `0.25` | `1.00` |
| `sear_y_3` | `0.05` | `0.01` | `0.09` |
| `prob_ris` | `0.117` | `0.076` | `0.13` |
| `mrp_coef` | `0.70` | `0.75` | `0.65` |
| `privat_r` | `0.07` | `0.05` | `0.10` |
| `social_r` | `0.03` | `0.01` | `0.05` |

> **Note: CE may generate 3-to-5 times while NC may generate 1.3-to-1.5 times in term of MRP. Thus, the base, best, and worst cases are (1*2 + 0.4*2)/4, (1*2 + 0.5*2)/4 (1*2 + 0.3*2)/4 where 4 are trainees and 2 each is CE and NC, respectively.**

## 8. Expected Script Output

Based on the formulas and parameters in `main.R`, the expected printed results for baseline are:

| Scenario | NPV | SNPV |
| :-- | --: | --: |
| Base Case | `$51,099,914` | `$65,670,956` |
| Best Case | `$93,584,534` | `$163,815,802` |
| Worst Case | ` -$95,607,626` | `-$235,058,570` |

## 9. Implementation Notes

The main function is:

```r
npv_calc <- function(
  COE_util = 0.50,
  sear_y_2 = 0.50,
  sear_y_3 = 0.05,
  prob_ris = 0.117,
  mrp_coef = 0.05,
  privat_r = 0.07,
  social_r = 0.03
)
```

It returns a list with:

| Return Field | Description |
| :-- | :-- |
| `data` | Full simulated trainee-year panel. |
| `npv` | Private-rate discounted NPV. |
| `snpv` | Social-rate discounted NPV minus the NSF award. |

The script runs `npv_calc()` once for each scenario and prints the NPV and SNPV values.

## 10. Citations for Cost and Benefit Assumptions

The current script does not store citations directly, but the cost and benefit assumptions are justified by the source set from the prior BCA document:

- ASPE standard regulatory impact analysis values: [https://aspe.hhs.gov/sites/default/files/documents/2d83af5823915d81871334ee08ad03d9/Standard-RIA-Values-2026.pdf](https://aspe.hhs.gov/sites/default/files/documents/2d83af5823915d81871334ee08ad03d9/Standard-RIA-Values-2026.pdf)
- Gallaudet graduate tuition reference: [https://gallaudet.edu/finance/student-financial-services/tuition/#graduate](https://gallaudet.edu/finance/student-financial-services/tuition/#graduate)
- National Deaf Center employment and earnings dashboard: [https://dashboard.nationaldeafcenter.org/?main=Employment%2FEarnings+by+Education&attr=overall&chart_type=levels&status=Median+Earnings](https://dashboard.nationaldeafcenter.org/?main=Employment%2FEarnings+by+Education&attr=overall&chart_type=levels&status=Median+Earnings)
- NSF Graduate Research Fellowship Program funding reference: [https://www.nsf.gov/funding/opportunities/grfp-nsf-graduate-research-fellowship-program](https://www.nsf.gov/funding/opportunities/grfp-nsf-graduate-research-fellowship-program)
- BLS software developer occupational employment and wage statistics: [https://www.bls.gov/oes/2022/may/oes151252.htm](https://www.bls.gov/oes/2022/may/oes151252.htm)
- Fokal machine learning engineer salary reference: [https://www.fokal.com/ai-seo-research/machine-learning-engineer-salary/](https://www.fokal.com/ai-seo-research/machine-learning-engineer-salary/)
- BLS local area unemployment statistics: [https://www.bls.gov/lau/stalt.htm](https://www.bls.gov/lau/stalt.htm)
- SHRM non-executive talent acquisition benchmarking baseline: [https://www.shrm.org/topics-tools/research/recruiting-benchmarking](https://www.shrm.org/topics-tools/research/recruiting-benchmarking)
- Technical and engineering sourcing premium metrics: [https://interviewcost.com/shrm-cost-per-hire](https://interviewcost.com/shrm-cost-per-hire)
- Computing Productivity: Firm-Level Evidence: [doi:10.1162/003465303772815736](https://doi.org/10.1162/003465303772815736)
- Monopsony in the U.S. Labor Market: [https://ideas.repec.org/p/upj/weupjo/22-364.html](https://ideas.repec.org/p/upj/weupjo/22-364.html)
- Social-belonging intervention: [https://www-science-org.ezproxy.lib.utexas.edu/doi/pdf/10.1126/science.ade4420](https://www-science-org.ezproxy.lib.utexas.edu/doi/pdf/10.1126/science.ade4420)
