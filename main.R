library(dplyr)
library(tidyr)
library(scales)
library(ggplot2)

# Parameters Matrix ------------------------------------------------------------
parameter_CE_target_wage=155350   # Target income CE is willing to give up to get
parameter_NC_target_wage=99234.37 # Target income NC is willing to give up to get
parameter_CE_old_wage=145906.04   # The old income CE had before enrollment. 
parameter_NC_old_wage=84295.86    # The old income NC had before enrollment. 
parameter_stipend=37000           # Annual stipend for funded trainees during training years. 
parameter_COE_wage=16000          # Annual cost-of-education allocation used for funded trainees.
parameter_intern_cost=2500        # Industry internship cost applied in trainee experience year 1.
parameter_onboard_NC=4700         # One-time recruitment friction applied in experience year 2 for non-coders.
parameter_onboard_CE=6200         # One-time specialized onboarding friction applied in experience year 2 for coding experts.
parameter_attrition_rate = 0.23   # Master's attrition is that from Council of Graduate School

# Counterfactual----------------------------------------------------------------
npv_calc_utility <- function(COE_util = 0.50, 
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
                             onboard_CE=parameter_onboard_CE){
  
  time_horizon <- 0:34
  cohort_1 <- data.frame(
    trainee_id   = 1:4,
    type         = c("FT-CE", "NT-CE", "FT-NC", "NT-NC"),
    t_start      = 0
  )
  
  cohorts_rest_list <- list()
  current_ft_total <- 2 + (4 * 2)
  
  for (cohort_idx in 1:4) {
    # Start with the baseline 4 trainees for this cohort
    base_types <- c("FT-CE", "NT-CE", "FT-NC", "NT-NC")
    added_types <- c()
    
    if (add_to_each_new_cohort > 0) {
      # Loop through the number of trainees to add to this cohort
      # We add them in balanced pairs or blocks to preserve CE == NC
      for (i in seq(1, add_to_each_new_cohort, by = 2)) {
        
        # Check if we have room under the 25 FT 5-year budget ceiling to add 1 more FT pair
        # (1 FT-CE and 1 FT-NC keeps CE/NC balanced and adds 2 to the FT count)
        if (current_ft_total + 2 <= 25) {
          added_types <- c(added_types, "FT-CE", "FT-NC")
          current_ft_total <- current_ft_total + 2
        } else {
          # If FT is capped out at 25, the website recruits Non-Funded trainees instead
          added_types <- c(added_types, "NT-CE", "NT-NC")
        }
      }
    }
    
    # Combine baseline and added trainees for this specific cohort year
    cohorts_rest_list[[cohort_idx]] <- data.frame(
      type    = c(base_types, added_types),
      t_start = cohort_idx
    )
  }
  
  metadata <- bind_rows(cohort_1, bind_rows(cohorts_rest_list)) %>%
    mutate(trainee_id = row_number())
  
  df_list <- list()
  for (current_time in time_horizon) {
    df_list[[as.character(current_time)]] <- metadata %>%
      filter(t_start <= current_time) %>%
      mutate(t = current_time, t_exp = t - t_start) %>%
      filter(t_exp <= 29) 
  }
  sim_df <- bind_rows(df_list)
  
  sim_df <- sim_df %>%
    mutate(
      # --- PRE-GRADUATION PHASE ---
      COE_Stipend = ifelse(grepl("FT-", type) & t_exp <= 1, COE_wage * COE_util + stipend, 0),
      
      # Safety Floor to prevent log(0) -> -Inf
      stipend_floor = ifelse(COE_Stipend > 0, COE_Stipend, 1),
      
      # Worker Training Phase Welfare Change (Log Utility converted to EV Dollars)
      work_deficit_i = case_when(
        t_exp < 2 & type == "FT-CE" ~ CE_old_wage * (log(stipend_floor) - log(CE_old_wage)),
        t_exp < 2 & type == "FT-NC" ~ NC_old_wage * (log(stipend_floor) - log(NC_old_wage)),
        t_exp < 2 & type == "NT-NC" ~ NC_old_wage * (log(1) - log(NC_old_wage)), # Infinite loss bounded to $1 floor
        TRUE ~ 0 # NT-CE retains their baseline wage, utility change is 0
      ),
      
      intern_cost_1 = ifelse(t_exp == 1, intern_cost, 0),
      
      # --- POST-GRADUATION PHASE ---
      old_wage = case_when(
        t_exp >= 2 & grepl("-CE", type) ~ CE_old_wage,
        t_exp >= 2 & grepl("-NC", type) ~ NC_old_wage,
        TRUE ~ 0
      ),
      comp_market = case_when(
        t_exp >= 2 & grepl("-CE", type) ~ CE_target_wage,
        t_exp >= 2 & grepl("-NC", type) ~ NC_target_wage,
        TRUE ~ 0
      ),
      
      # Calculate actual realized take-home pay
      realized_wage = case_when(
        t_exp == 2 ~ comp_market * (1 - sear_y_2) * (1 - prob_ris),
        t_exp >= 3 ~ comp_market * (1 - sear_y_3) * (1 - prob_ris),
        TRUE ~ 0
      ),
      
      # Safety Floor for realized wage to prevent log(0) in Worst Case scenarios
      realized_wage_floor = ifelse(realized_wage > 0, realized_wage, 1),
      
      # Worker Post-Grad Welfare Change (Log Utility converted to EV Dollars)
      work_surplus_i = ifelse(t_exp >= 2, 
                              (1 - attrition_rate) * (comp_market * (log(realized_wage_floor) - log(old_wage))), 
                              0),
      
      # Firm Financial Surplus
      mrp = ifelse(t_exp >= 2, comp_market * (1 + mrp_coef), 0),
      business_surplus_i = ifelse(t_exp >= 2, (1 - attrition_rate) * (mrp - realized_wage), 0),
      
      onboard_cost_2 = case_when(
        t_exp == 2 & grepl("-CE", type) ~ onboard_CE,
        t_exp == 2 & grepl("-NC", type) ~ onboard_NC,
        TRUE ~ 0
      ),
      
      # --- SOCIETAL DEADWEIGHT LOSS ---
      deadweight_loss_friction_i = ifelse(t_exp >= 2, 
                                          (1 - attrition_rate) * (comp_market * (log(comp_market) - log(realized_wage_floor))), 
                                          0),
      
      # --- LIFECYCLE TOTALS ---
      costs        =  intern_cost_1 + onboard_cost_2,
      social_costs = costs + deadweight_loss_friction_i,
      
      # Total Private Benefit combines Firm Wealth + Worker Welfare
      benefits     = business_surplus_i + work_surplus_i + work_deficit_i,
      
      individual_time_npv  = (benefits - costs) / ((1 + privat_r) ^ t),
      individual_time_snpv = (benefits - social_costs) / ((1 + social_r) ^ t)
    )
  
  total_npv  <- sum(sim_df$individual_time_npv)
  total_snpv <- sum(sim_df$individual_time_snpv)
  
  return(list(data = sim_df, npv = total_npv, snpv = total_snpv))
}

# Base-Case, Best-Case, and Worst-Case Value
base_util  <- npv_calc_utility()
best_util  <- npv_calc_utility(COE_util=0.90, 
                               sear_y_2=0.25, 
                               sear_y_3=0.01, 
                               prob_ris=0.076, 
                               mrp_coef=0.75, 
                               privat_r=0.05, 
                               social_r=0.01)
worst_util <- npv_calc_utility(COE_util=0.10, 
                               sear_y_2=1.00, 
                               sear_y_3=0.09, 
                               prob_ris=0.13, 
                               mrp_coef=0.65, 
                               privat_r=0.1, 
                               social_r=0.05)

print(paste("Base-Case NPV:", dollar(base_util$npv), " | SNPV:", dollar(base_util$snpv)))
print(paste("Best-Case NPV:", dollar(best_util$npv), " | SNPV:", dollar(best_util$snpv)))
print(paste("Worst-Case NPV:", dollar(worst_util$npv), " | SNPV:", dollar(worst_util$snpv)))

# Plot--------------------------------------------------------------------------
get_cum_snpv <- function(res,scenario_name) {
  res$data %>%
    group_by(t) %>%
    summarise(annual_snpv = sum(individual_time_snpv, na.rm = TRUE)) %>%
    ungroup() %>%
    mutate(
      cumulative_snpv = cumsum(annual_snpv),
      scenario = scenario_name
    )
}

base_df  <- get_cum_snpv(base_util,"Baseline") 
best_df  <- get_cum_snpv(best_util,"Best Case")
worst_df <- get_cum_snpv(worst_util,"Worst Case")

ribbon_data <- base_df %>%
  select(t, baseline = cumulative_snpv) %>%
  left_join(select(best_df, t, best = cumulative_snpv), by = "t") %>%
  left_join(select(worst_df, t, worst = cumulative_snpv), by = "t")

lbl_best     <- paste0("Best Case (",     dollar_format(scale_cut = cut_short_scale(), accuracy = 0.1)(best_util$snpv), ")")
lbl_baseline <- paste0("Base Case (",     dollar_format(scale_cut = cut_short_scale(), accuracy = 0.1)(base_util$snpv), ")")
lbl_worst    <- paste0("Worst Case (",    dollar_format(scale_cut = cut_short_scale(), accuracy = 0.1)(worst_util$snpv), ")")

manual_linetypes <- c("dotted", "dashed", "twodash")
names(manual_linetypes) <- c(lbl_best, lbl_baseline, lbl_worst)

p <- ggplot(ribbon_data, aes(x = t)) +
  geom_hline(yintercept = 0, color = "black", linetype = "solid", linewidth = 0.4, alpha = 0.5) +
  geom_ribbon(aes(ymin = worst, ymax = best), fill = "black", alpha = 0.08) +
  
  geom_line(aes(y = best,     linetype = lbl_best),     color = "black", linewidth = 0.5) +  
  geom_line(aes(y = baseline, linetype = lbl_baseline), color = "black", linewidth = 1) +
  geom_line(aes(y = worst,    linetype = lbl_worst),    color = "black", linewidth = 0.5) + 
  
  scale_linetype_manual(values = manual_linetypes, breaks = c(lbl_best, lbl_baseline, lbl_worst)) +
  scale_x_continuous(breaks = seq(0, 34, by = 5), expand = expansion(mult = c(0.02, 0.05))) +
  scale_y_continuous(labels = label_dollar(scale = 1e-6, suffix = "M")) +
  labs(
    x = "Simulation Year (t)",
    y = NULL,
    linetype = NULL 
  ) +
  theme_classic() + # Strip default theme settings first
  theme(
    # FORCE ALL TEXT TO EXACTLY 11 PT
    axis.title.x = element_text(size = 11, color = "black", margin = margin(t = 10)),
    axis.title.y = element_text(size = 11, color = "black", margin = margin(r = 10)),
    axis.text.x  = element_text(size = 11, color = "black"),
    axis.text.y  = element_text(size = 11, color = "black"),
    legend.title = element_text(size = 11, color = "black", face = "bold"),
    legend.text  = element_text(size = 11, color = "black"),
    
    # Layout Adjustments
    axis.line       = element_line(color = "black", linewidth = 0.5),
    legend.position = "top"
  )

ggsave(
  filename   = "simulation_plot.png", 
  plot       = p, 
  device     = "png", 
  dpi        = 300,        # High print resolution
  width      = 6.5,        # Width in inches (standard page width)
  height     = 4.5,        # Aspect ratio control
  units      = "in"
)

# ACT-02------------------------------------------------------------------------
# ACT-02: GIEI and other events: Develop GIEI centralized approval guidelines 
# and plan implementations from day one, not ad hoc.

# This implies that GIEI events may produce the weak links to reduce job 
# frictions.

# The assumption is:
# - Base-Case For Act 02, the base case prevents 2 trainees per cohort from 
# spending on a job search by reducing from 6 months (50% = 6/12) to 1 month
# (8.3% = 1/12). Thus, 2/4 trainees x 1/12 = 2/48 (4.17%) in search 2 year.
# Input: .5 - 2/48

# - Best case is 3 trainees per cohort. Thus, 3/4 x 1/12 = 3/48 (0.0625) in 
# search 2 year.
# Input: .25 - 3/48

# - Worst case is 1 trainee per cohort. Thus, 1/4 trainees x 1/12 = 1/48 (2.08%)
# in search 2 year.
# Input: 1 - 1/48

# Base-Case Value
base_ACT02<-npv_calc_utility(sear_y_2 = .5 - 2/48)
best_ACT02<-npv_calc_utility(COE_util = 0.90, 
                     sear_y_2 = .25 - 3/48, 
                     sear_y_3 = 0.01, 
                     prob_ris = 0.076, 
                     mrp_coef = 0.75,
                     privat_r = 0.05,
                     social_r = 0.01)
worst_ACT02<-npv_calc_utility(COE_util = 0.10, 
                      sear_y_2 = 1 - 1/48, 
                      sear_y_3 = 0.09, 
                      prob_ris = 0.13, 
                      mrp_coef = 0.65,
                      privat_r = 0.1,
                      social_r = 0.05)

print(paste("ACT-02 Base: Difference:",dollar_format()(base_ACT02$npv - base_util$npv),"| Social Difference:",dollar_format()(base_ACT02$snpv - base_util$snpv)))
print(paste("ACT-02 Best: Difference:",dollar_format()(best_ACT02$npv - best_util$npv),"| Social Difference:",dollar_format()(best_ACT02$snpv - best_util$snpv)))
print(paste("ACT-02 Worst: Difference:",dollar_format()(worst_ACT02$npv - worst_util$npv),"| Social Difference:",dollar_format()(worst_ACT02$snpv - worst_util$snpv)))


# ACT-03------------------------------------------------------------------------
# ACT-03: Coding course: Develop a self-paced online course or a limited 
# introduction to coding.

# This implies that NC turns into CE at entry level and MRP increases to 1.
# BLS report in May 2022 is 25th percentile annual wage is $96,790, adjusting to
# $103,278.44 in October 2025.

parameter_Entry_CE_target_wage=103278.44

base_ACT03  <- npv_calc_utility(NC_target_wage = parameter_Entry_CE_target_wage, 
                                onboard_NC=parameter_onboard_CE, 
                                mrp_coef=1)
best_ACT03 <- npv_calc_utility(NC_target_wage = parameter_Entry_CE_target_wage, 
                               onboard_NC=parameter_onboard_CE, 
                               COE_util=0.90, 
                               sear_y_2=0.25, 
                               sear_y_3=0.01, 
                               prob_ris=0.076, 
                               mrp_coef=1, 
                               privat_r=0.05, 
                               social_r=0.01)
worst_ACT03 <- npv_calc_utility(NC_target_wage = parameter_Entry_CE_target_wage, 
                                onboard_NC=parameter_onboard_CE, 
                                COE_util=0.10, 
                                sear_y_2=1.00, 
                                sear_y_3=0.09, 
                                prob_ris=0.13, 
                                mrp_coef=1, 
                                privat_r=0.1, 
                                social_r=0.05)

print(paste("ACT-03 Base: Difference:", dollar_format()(base_ACT03$npv - base_util$npv), 
            "| Social Difference:", dollar_format()(base_ACT03$snpv - base_util$snpv)))

print(paste("ACT-03 Best: Difference:", dollar_format()(best_ACT03$npv - best_util$npv), 
            "| Social Difference:", dollar_format()(best_ACT03$snpv - best_util$snpv)))

print(paste("ACT-03 Worst: Difference:", dollar_format()(worst_ACT03$npv - worst_util$npv), 
            "| Social Difference:", dollar_format()(worst_ACT03$snpv - worst_util$snpv)))

# ACT-04------------------------------------------------------------------------
# ACT-04: Program Website: Show resources with details on funding, 
# travel opportunities, prerequisite knowledge, professional development 
# tracking tool, and event calendar as a recruitment tool.

# This implies that this website helps attract more trainees per cohort. One 
# trainee mentioned that they tried to use that to recruit them.

# The assumption is:
# - Base-Case: recruits 6 trainees per cohort after first cohort due to website.

# - Best case: recruits 10 trainees per cohort after first cohort due to website.

# - Best case: recruits 2 trainees per cohort after first cohort due to website.

base_ACT04<-npv_calc_utility(add_to_each_new_cohort = 6)
best_ACT04<-npv_calc_utility(add_to_each_new_cohort = 10,
                             COE_util = 0.90, 
                             sear_y_2 = .25, 
                             sear_y_3 = 0.01, 
                             prob_ris = 0.076, 
                             mrp_coef = 0.75,
                             privat_r = 0.05,
                             social_r = 0.01)
worst_ACT04<-npv_calc_utility(add_to_each_new_cohort = 2,
                              COE_util = 0.10, 
                              sear_y_2 = 1, 
                              sear_y_3 = 0.09, 
                              prob_ris = 0.13, 
                              mrp_coef = 0.65,
                              privat_r = 0.1,
                              social_r = 0.05)

print(paste("ACT-04 Base: Difference:", dollar_format()(base_ACT04$npv - base_util$npv), 
            "| Social Difference:", dollar_format()(base_ACT04$snpv - base_util$snpv)))

print(paste("ACT-04 Best: Difference:", dollar_format()(best_ACT04$npv - best_util$npv), 
            "| Social Difference:", dollar_format()(best_ACT04$snpv - best_util$snpv)))

print(paste("ACT-04 Worst: Difference:", dollar_format()(worst_ACT04$npv - worst_util$npv), 
            "| Social Difference:", dollar_format()(worst_ACT04$snpv - worst_util$snpv)))

# ACT-06------------------------------------------------------------------------
# ACT-06: Description: Organize intentional, low-pressure social events for the cohort to 
# build community belongingness and mitigate isolation-driven attrition.
#
# Empirical Anchor: Walton et al. (2023) in Science established a 3-way interaction 
# CATE of 0.013 for belonging interventions delivered to historically marginalized groups
# within supportive contexts ("belonging affordances"). 
#
# Execution Variance Bounds:
#   - Base-Case:  Replicates literature exactly (Δ = 0.013) -> 0.23 - 0.013
#   - Best-Case:  Optimized, culturally authentic ASL space (Δ = 0.019) -> 0.23 - 0.019
#   - Worst-Case: Underfunded, low-engagement execution (Δ = 0.007) -> 0.23 - 0.007

base_ACT06<-npv_calc_utility(attrition_rate = parameter_attrition_rate - 0.013)
best_ACT06<-npv_calc_utility(attrition_rate = parameter_attrition_rate - 0.019,
                             COE_util = 0.90, 
                             sear_y_2 = .25, 
                             sear_y_3 = 0.01, 
                             prob_ris = 0.076, 
                             mrp_coef = 0.75,
                             privat_r = 0.05,
                             social_r = 0.01)
worst_ACT06<-npv_calc_utility(attrition_rate = parameter_attrition_rate - 0.007,
                              COE_util = 0.10, 
                              sear_y_2 = 1, 
                              sear_y_3 = 0.09, 
                              prob_ris = 0.13, 
                              mrp_coef = 0.65,
                              privat_r = 0.1,
                              social_r = 0.05)


print(paste("ACT-06 Base: Difference:", dollar_format()(base_ACT06$npv - base_util$npv), 
            "| Social Difference:", dollar_format()(base_ACT06$snpv - base_util$snpv)))

print(paste("ACT-06 Best: Difference:", dollar_format()(best_ACT06$npv - best_util$npv), 
            "| Social Difference:", dollar_format()(best_ACT06$snpv - best_util$snpv)))

print(paste("ACT-06 Worst: Difference:", dollar_format()(worst_ACT06$npv - worst_util$npv), 
            "| Social Difference:", dollar_format()(worst_ACT06$snpv - worst_util$snpv)))


# ACT-07------------------------------------------------------------------------
# Recruitment: Invest in a dedicated role or coordinator to recruit students 
# and external partners like IAB and prospects.

# This implies that the coordinator scales cohort sizes AND directly places a 
# portion of the cohort into 1-month fast-track jobs (1/12 friction) via the IAB,
# dropping the weighted average search lag (sear_y_2) across the whole cohort.

# Base-Case: Add 4 trainees.  2 out of 4 baseline slots skip search friction
base_ACT07  <- npv_calc_utility(add_to_each_new_cohort = 4,
                                sear_y_2               = 0.50 - (2/48))

# Best-Case: Add 6 trainees. 3 out of 4 baseline slots skip search friction.
best_ACT07  <- npv_calc_utility(add_to_each_new_cohort = 6,
                                sear_y_2               = 0.25 - (3/48),
                                COE_util               = 0.90, 
                                sear_y_3               = 0.01, 
                                prob_ris               = 0.076, 
                                mrp_coef               = 0.75,
                                privat_r               = 0.05,
                                social_r               = 0.01)

# Worst-Case: Failed role. Adds 2 trainees. 1 slot gets placed,
# but the rest face unmitigated 100% friction (sear_y_2 = 1.0) due to lack of support.
worst_ACT07 <- npv_calc_utility(add_to_each_new_cohort = 2, 
                                sear_y_2               = 1.00 - (1/48),
                                COE_util               = 0.10, 
                                sear_y_3               = 0.09, 
                                prob_ris               = 0.130, 
                                mrp_coef               = 0.65,
                                privat_r               = 0.10,
                                social_r               = 0.05)

print(paste("ACT-07 Base: Difference:", dollar_format()(base_ACT07$npv - base_util$npv), 
            "| Social Difference:", dollar_format()(base_ACT07$snpv - base_util$snpv)))

print(paste("ACT-07 Best: Difference:", dollar_format()(best_ACT07$npv - best_util$npv), 
            "| Social Difference:", dollar_format()(best_ACT07$snpv - best_util$snpv)))

print(paste("ACT-07 Worst: Difference:", dollar_format()(worst_ACT07$npv - worst_util$npv), 
            "| Social Difference:", dollar_format()(worst_ACT07$snpv - worst_util$snpv)))
# ACT-08------------------------------------------------------------------------
# Gitea + Medallion in Gallaudet University for AI foundation

# This implies that students have hand-on experience with technology to allow,
# them to do data annotation, ML training, and mathematical inventions. This
# may be characterized as technology frontiers.

# The article "The Skill Premium in Times of Rapid Technological Change"
# mentioned that 57% of jobs involving a new technology require a college 
# degree compared to 34% of jobs involving 80-aged technologies. 32% for 
# college premium is due to technology shock. Thus:
# impact = search_y_X * (1- search_y_X * 16%)

# Because (0% * NC x 2 + 32% x CE)/4 = 16%
# Assume that being frontier increases MRP by 0.01.

# Base-Case: Apply the 16% tech shock discount to Year 2 friction and add the 0.01 MRP lift.
base_ACT08  <- npv_calc_utility(sear_y_2 = 0.50 * (1 - (0.50 * 0.16)),
                                sear_y_3=0.05 * (1 - (0.05 * 0.16)), 
                                mrp_coef = 0.70 + 0.01)
# Best-Case: Fully optimized implementation. The tech shock discount compounds with
# an optimized baseline search parameter (0.25) and captures the 0.01 frontier lift.
best_ACT08  <- npv_calc_utility(sear_y_2 = 0.25 * (1 - (0.25 * 0.16)), # = 0.24
                                mrp_coef = 0.75 + 0.01,
                                COE_util=0.90, 
                                sear_y_3=0.01 * (1 - (0.01 * 0.16)), 
                                prob_ris=0.076, 
                                privat_r=0.05, 
                                social_r=0.01)

# Worst-Case: Disorganized execution / "Data Swamp". Trainees fail to realize the 
# tech shock discount or the productivity lift due to severe technical friction.
worst_ACT08 <- npv_calc_utility(sear_y_2 = 1.00 * (1 - (1.00 * 0.00)), # No discount
                                mrp_coef = 0.65,                      # Systemic penalty
                                sear_y_3 = 0.09 * (1 - (0.09 * 0.00)), 
                                privat_r = 0.10,
                                social_r = 0.05,
                                COE_util=0.10, 
                                prob_ris=0.13)

print(paste("ACT-08 Base: Difference:", dollar_format()(base_ACT08$npv - base_util$npv), 
            "| Social Difference:", dollar_format()(base_ACT08$snpv - base_util$snpv)))

print(paste("ACT-08 Best: Difference:", dollar_format()(best_ACT08$npv - best_util$npv), 
            "| Social Difference:", dollar_format()(best_ACT08$snpv - best_util$snpv)))

print(paste("ACT-08 Worst: Difference:", dollar_format()(worst_ACT08$npv - worst_util$npv), 
            "| Social Difference:", dollar_format()(worst_ACT08$snpv - worst_util$snpv)))
