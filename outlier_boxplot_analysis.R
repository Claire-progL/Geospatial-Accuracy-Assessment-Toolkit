# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Check and install necessary packages
if (!require(readxl)) install.packages("readxl", dependencies = TRUE)
if (!require(ggplot2)) install.packages("ggplot2", dependencies = TRUE)
if (!require(writexl)) install.packages("writexl", dependencies = TRUE)
if (!require(dplyr)) install.packages("dplyr", dependencies = TRUE)
if (!require(tidyr)) install.packages("tidyr", dependencies = TRUE) # Added tidyr package for uncount

# Load packages
library(readxl)
library(ggplot2)
library(writexl)
library(dplyr)
library(tidyr) 

# Create analysis function
analyze_vegetation_index <- function(file_name, index_name, max_outliers = 5) {
  tryCatch({
    # Check if file exists
    if (!file.exists(file_name)) {
      stop(paste(file_name, "not found!"))
    }
    
    # Read data and uncount based on the Count column
    data <- read_excel(file_name) %>%
      uncount(weights = Count) # Expand observations based on the Count column
      
    # Create results list
    all_results <- list()
    
    # Analyze each region separately
    for(current_region in unique(data$region)) {
      # Filter data for the current region
      region_data <- data %>% filter(region == current_region)
      
      # 1. Calculate statistics and thresholds
      # Calculate statistics grouped by health status
      health_stats <- region_data %>%
        group_by(health) %>%
        summarise(
          Mean = mean(DN),
          SD = sd(DN),
          P25 = quantile(DN, 0.25), # 25th percentile
          P75 = quantile(DN, 0.75), # 75th percentile
          Min = min(DN),
          Max = max(DN)
        )
        
      # Calculate thresholds based on the paper's method
      # Calculate thresholds for Good-Moderate and Moderate-Poor
      thresholds_paper <- data.frame(
        Method = "Paper Method",
        Good_Moderate = (health_stats$P75[health_stats$health == "Moderate"] +
                         health_stats$P25[health_stats$health == "Good"]) / 2,
        Moderate_Poor = (health_stats$P75[health_stats$health == "Poor"] +
                         health_stats$P25[health_stats$health == "Moderate"]) / 2
      )
      
      # Create final threshold criteria
      final_thresholds <- data.frame(
        Health_Status = c("Good", "Moderate", "Poor"),
        Range = c(
          sprintf(">%.3f", thresholds_paper$Good_Moderate),
          sprintf("%.3f to %.3f", thresholds_paper$Moderate_Poor, thresholds_paper$Good_Moderate),
          sprintf("<%.3f", thresholds_paper$Moderate_Poor)
        )
      )
      
      # Store the current region's results in the list
      all_results[[paste0(current_region, "_Health_Statistics")]] <- health_stats
      all_results[[paste0(current_region, "_Thresholds")]] <- thresholds_paper
      all_results[[paste0(current_region, "_Final_Thresholds")]] <- final_thresholds
    }
    
    # 2. Calculate boxplot statistics
    results_list <- list()
    for(h in unique(data$health)) {
      for(r in unique(data$region)) {
        group_data <- data$DN[data$health == h & data$region == r]
        q1 <- quantile(group_data, 0.25)
        q3 <- quantile(group_data, 0.75)
        iqr <- q3 - q1
        lower_bound <- q1 - 1.5 * iqr
        upper_bound <- q3 + 1.5 * iqr
        
        outliers <- group_data[group_data < lower_bound | group_data > upper_bound]
        
        # Keep only up to max_outliers outliers
        if (length(outliers) > max_outliers) {
          outliers <- outliers[1:max_outliers]
        }
        
        results_list[[paste(h, r, sep="_")]] <- data.frame(
          Health = h,
          Region = r,
          P25 = q1,
          Median = median(group_data),
          P75 = q3,
          IQR = iqr,
          Mean = mean(group_data),
          Min = min(group_data),
          Max = max(group_data),
          Lower_Bound = lower_bound,
          Upper_Bound = upper_bound,
          Outliers_Count = length(outliers),
          Outliers = if(length(outliers) > 0) paste(round(outliers, 4), collapse = "; ") else "None"
        )
      }
    }
    
    boxplot_stats <- do.call(rbind, results_list)
    rownames(boxplot_stats) <- NULL
    
    # Add boxplot statistics to the results list
    all_results[["Boxplot_Statistics"]] <- boxplot_stats
    
    # 3. Create boxplot
    p <- ggplot(data, aes(x = health, y = DN)) +
      geom_boxplot(aes(fill = region),
                   outlier.shape = 8,
                   outlier.size = 3,
                   outlier.colour = "red",
                   position = position_dodge(0.8),
                   width = 0.7,
                   staplewidth = 0.3) +
      scale_fill_manual(values = c("pink", "lightblue")) +
      theme_classic() +
      theme(
        panel.background = element_rect(fill = "white", color = "black"),
        plot.background = element_rect(fill = "white", color = NA),
        legend.background = element_rect(fill = "white", color = NA),
        axis.text = element_text(size = 10),
        axis.title = element_text(size = 12),
        legend.title = element_text(size = 12),
        legend.text = element_text(size = 10),
        plot.margin = unit(c(1,1,1,1), "cm")
      ) +
      labs(
        x = "Health",
        y = index_name,
        fill = "Region",
        title = paste(index_name, "Distribution by Health Status and Region")
      ) +
      stat_summary(fun = mean,
                   geom = "point",
                   aes(group = region),
                   shape = 15,
                   size = 3,
                   color = "blue",
                   position = position_dodge(0.8)) +
      stat_summary(fun = mean,
                   geom = "text",
                   aes(group = region,
                       label = sprintf("Mean: %.3f", after_stat(y))),
                   position = position_dodge(0.8),
                   vjust = -2) +
      stat_summary(fun = median,
                   geom = "text",
                   aes(group = region,
                       label = sprintf("Median: %.3f", after_stat(y))),
                   position = position_dodge(0.8),
                   vjust = 4)
                   
    # 4. Save results
    write_xlsx(all_results, paste0(index_name, "_analysis.xlsx"))
    print(paste("Statistics saved to", paste0(index_name, "_analysis.xlsx")))
    
    # Save plot
    ggsave(paste0(index_name, "_boxplot.png"), p, width = 12, height = 8, dpi = 300)
    print(paste("Plot saved to", paste0(index_name, "_boxplot.png")))
    
  }, error = function(e) {
    print(paste("Error occurred:", e$message))
  })
}

# Analyze CIred-edge index
print("Analyzing CIred-edge index...")
analyze_vegetation_index("CIred-edge.xls", "CIred-edge")
