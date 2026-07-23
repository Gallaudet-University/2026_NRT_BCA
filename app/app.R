library(shiny)
library(tidyverse)
library(plotly)
library(bslib)

# Define UI
ui <- page_sidebar(
  title = "Workforce Development NPV & Utility Simulator",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  
  sidebar = sidebar(
    width = 380,
    title = "Simulation Parameters",
    
    accordion(
      accordion_panel(
        "Wages & Stipends",
        sliderInput("CE_target_wage", "CE Target Wage ($)", min = 40000, max = 160000, value = 155350, step = 50),
        sliderInput("NC_target_wage", "NC Target Wage ($)", min = 30000, max = 160000, value = 99235, step = 50),
        sliderInput("COE_util", "COE utilization", min = 0, max = 1, value = 0.5, step = 0.01),
        sliderInput("add_to_each_new_cohort", "Add to Each New Cohort", min = 0, max = 10, value = 0, step = 2)
      ),
      accordion_panel(
        "Frictions & Attrition",
        sliderInput("sear_y_2", "Year 2 Search Friction", min = 0, max = 1, value = 0.50, step = 0.01),
        sliderInput("sear_y_3", "Year 3+ Search Friction", min = 0.01, max = 0.1, value = 0.05, step = 0.01),
        sliderInput("prob_ris", "Probability of Risk", min = 0.076, max = 0.13, value = 0.117, step = 0.001),
        sliderInput("attrition_rate", "Annual Attrition Rate", min = 0.211, max = 0.23, value = 0.23, step = 0.001)
      ),
      accordion_panel(
        "Financial & Firm Rates",
        sliderInput("privat_r", "Private Discount Rate", min = 0.05, max = 0.09, value = 0.07, step = 0.01),
        sliderInput("social_r", "Social Discount Rate", min = 0.01, max = 0.05, value = 0.03, step = 0.01),
        sliderInput("mrp_coef", "Firm MRP Coefficient", min = 0.65, max = 1, value = 0.70, step = 0.05)
      )
    )
  ),
  
  # Main Layout
  layout_columns(
    col_widths = c(6, 6),
    value_box(
      title = "Total Private NPV",
      value = textOutput("value_npv"),
      showcase = icon("briefcase"),
      theme = "primary"
    ),
    value_box(
      title = "Total Social NPV",
      value = textOutput("value_snpv"),
      showcase = icon("globe"),
      theme = "success"
    )
  ),
  
  card(
    card_header("Cumulative Net Present Value Over 35-Year Horizon"),
    plotlyOutput("npv_plot", height = "450px")
  )
)

# Define Server Logic
# Define Server Logic
server <- function(input, output, session) {
  
  # Reactive function running the aligned pipeline algorithm
  sim_results <- reactive({
    time_horizon <- 0:34
    
    cohort_1 <- data.frame(
      trainee_id = 1:4,
      type       = c("FT-CE", "NT-CE", "FT-NC", "NT-NC"),
      t_start    = 0
    )
    
    cohorts_rest_list <- list()
    current_ft_total <- 2 + (4 * 2) 
    
    for (cohort_idx in 1:4) {
      base_types <- c("FT-CE", "NT-CE", "FT-NC", "NT-NC")
      added_types <- c()
      
      if (input$add_to_each_new_cohort > 0) {
        for (i in seq(1, input$add_to_each_new_cohort, by = 2)) {
          if (current_ft_total + 2 <= 25) {
            added_types <- c(added_types, "FT-CE", "FT-NC")
            current_ft_total <- current_ft_total + 2
          } else {
            added_types <- c(added_types, "NT-CE", "NT-NC")
          }
        }
      }
      
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
    
    # Structural constants explicitly frozen per user parameters
    CE_old_wage <- 145906.04
    NC_old_wage <- 84295.86
    COE_wage <- 16000
    stipend <- 37000
    intern_cost <- 2500
    onboard_CE <- 6200
    onboard_NC <- 4700
    
    sim_df <- sim_df %>%
      mutate(
        # --- PRE-GRADUATION PHASE ---
        COE_Stipend = ifelse(grepl("FT-", type) & t_exp <= 1, COE_wage * input$COE_util + stipend, 0),
        stipend_floor = ifelse(COE_Stipend > 0, COE_Stipend, 1),
        
        work_deficit_i = case_when(
          t_exp < 2 & type == "FT-CE" ~ CE_old_wage * (log(stipend_floor) - log(CE_old_wage)),
          t_exp < 2 & type == "FT-NC" ~ NC_old_wage * (log(stipend_floor) - log(NC_old_wage)),
          t_exp < 2 & type == "NT-NC" ~ NC_old_wage * (log(1) - log(NC_old_wage)),
          TRUE ~ 0
        ),
        
        intern_cost_1 = ifelse(t_exp == 1, intern_cost, 0),
        
        # --- POST-GRADUATION PHASE ---
        old_wage = case_when(
          t_exp >= 2 & grepl("-CE", type) ~ CE_old_wage,
          t_exp >= 2 & grepl("-NC", type) ~ NC_old_wage,
          TRUE ~ 0
        ),
        comp_market = case_when(
          t_exp >= 2 & grepl("-CE", type) ~ input$CE_target_wage,
          t_exp >= 2 & grepl("-NC", type) ~ input$NC_target_wage,
          TRUE ~ 0
        ),
        
        realized_wage = case_when(
          t_exp == 2 ~ comp_market * (1 - input$sear_y_2) * (1 - input$prob_ris),
          t_exp >= 3 ~ comp_market * (1 - input$sear_y_3) * (1 - input$prob_ris),
          TRUE ~ 0
        ),
        realized_wage_floor = ifelse(realized_wage > 0, realized_wage, 1),
        
        work_surplus_i = ifelse(t_exp >= 2, 
                                (1 - input$attrition_rate) * (comp_market * (log(realized_wage_floor) - log(old_wage))), 
                                0),
        
        mrp = ifelse(t_exp >= 2, comp_market * (1 + input$mrp_coef), 0),
        business_surplus_i = ifelse(t_exp >= 2, (1 - input$attrition_rate) * (mrp - realized_wage), 0),
        
        onboard_cost_2 = case_when(
          t_exp == 2 & grepl("-CE", type) ~ onboard_CE,
          t_exp == 2 & grepl("-NC", type) ~ onboard_NC,
          TRUE ~ 0
        ),
        
        # --- SOCIETAL DEADWEIGHT LOSS ---
        deadweight_loss_friction_i = ifelse(t_exp >= 2, 
                                            (1 - input$attrition_rate) * (comp_market * (log(comp_market) - log(realized_wage_floor))), 
                                            0),
        
        costs        = intern_cost_1 + onboard_cost_2,
        social_costs = costs + deadweight_loss_friction_i,
        benefits     = business_surplus_i + work_surplus_i + work_deficit_i,
        
        individual_time_npv  = (benefits - costs) / ((1 + input$privat_r) ^ t),
        individual_time_snpv = (benefits - social_costs) / ((1 + input$social_r) ^ t)
      )
    
    return(sim_df)
  })
  
  # NSF baseline penalty set precisely to 0
  nsf_award <- 0
  
  # Render absolute value metrics
  output$value_npv <- renderText({
    df <- sim_results()
    total_npv <- sum(df$individual_time_npv, na.rm = TRUE)
    paste0("$", format(round(total_npv), big.mark = ","))
  })
  
  output$value_snpv <- renderText({
    df <- sim_results()
    total_snpv <- sum(df$individual_time_snpv, na.rm = TRUE) - nsf_award
    paste0("$", format(round(total_snpv), big.mark = ","))
  })
  
  # Render clean cumulative chart timeline tracking
  output$npv_plot <- renderPlotly({
    plot_df <- sim_results() %>%
      group_by(t) %>%
      summarise(
        Annual_NPV = sum(individual_time_npv, na.rm = TRUE),
        Annual_SNPV = sum(individual_time_snpv, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(t) %>%
      mutate(
        Cum_NPV = cumsum(Annual_NPV),
        Cum_SNPV = cumsum(Annual_SNPV) - nsf_award
      )
    
    plot_ly(plot_df, x = ~t) %>%
      add_lines(y = ~Cum_NPV, name = "Private NPV", line = list(color = "#2C3E50", width = 3)) %>%
      add_lines(y = ~Cum_SNPV, name = "Social NPV (Net)", line = list(color = "#18BC9C", width = 3)) %>%
      layout(
        xaxis = list(title = "Simulation Year (t)"),
        yaxis = list(title = "Cumulative Asset Position ($)", tickformat = "$,"),
        hovermode = "x unified",
        legend = list(orientation = "h", y = -0.2)
      )
  })
}

# Run Application
shinyApp(ui = ui, server = server)