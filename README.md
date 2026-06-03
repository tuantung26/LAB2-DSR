# Simplified R Pipeline for Data Science Lab 2
# Topic: Analysis of Movie Blockbusters with Database Integration
# Author: Student

cat("=========================================\n")
cat("Starting Blockbusters Analysis Pipeline\n")
cat("=========================================\n\n")

# 1. ENVIRONMENT & LIBRARIES SETUP
# Load installed packages from the local library directory
.libPaths(c(file.path(getwd(), "r_libs"), .libPaths()))
library(DBI)

# 2. CONFIGURABLE DATABASE CONNECTION
# Options: "sqlite" (default local file) or "mysql" (local server)
db_type <- "sqlite" 

con <- NULL
if (db_type == "sqlite") {
  cat("[DB] Connecting to SQLite database (blockbusters.db)...\n")
  con <- dbConnect(RSQLite::SQLite(), "blockbusters.db")
} else {
  cat("[DB] Connecting to MySQL server...\n")
  con <- dbConnect(
    RMariaDB::MariaDB(),
    host = "127.0.0.1",
    port = 3306,
    username = "root",
    password = "", # Put your MySQL password here
    dbname = "blockbuster_db"
  )
}

# 3. DATABASE SETUP & DATA IMPORT
# Read raw CSV dataset
movies_raw <- read.csv("blockbusters.csv", stringsAsFactors = FALSE)

# Import dataset into database table
dbWriteTable(con, "blockbusters", movies_raw, overwrite = TRUE, row.names = FALSE)
cat("[DB] Imported 'blockbusters' table successfully.\n")

# Create and seed studio lookup table
studio_lookup_data <- data.frame(
  studio_name = c("Walt Disney Pictures", "Universal Pictures", "Warner Bros", "20th Century Fox", "Paramount Pictures", "Columbia Pictures", "Pixar", "Sony Pictures"),
  headquarters = c("Burbank, California, USA", "Universal City, California, USA", "Burbank, California, USA", "Los Angeles, California, USA", "Los Angeles, California, USA", "Culver City, California, USA", "Emeryville, California, USA", "Culver City, California, USA"),
  founded_year = c(1923, 1912, 1923, 1935, 1912, 1918, 1986, 1987),
  parent_company = c("The Walt Disney Company", "Comcast", "Warner Bros. Discovery", "The Walt Disney Company", "Paramount Global", "Sony Pictures Entertainment", "The Walt Disney Company", "Sony Group"),
  stringsAsFactors = FALSE
)
dbWriteTable(con, "studio_lookup", studio_lookup_data, overwrite = TRUE, row.names = FALSE)
cat("[DB] Created and seeded 'studio_lookup' table.\n")

# 4. SQL QUERY RETRIEVAL FROM R (JOIN requirement)
cat("\n--- Running JOIN Query in SQL from R ---\n")
join_query <- "
SELECT 
    s.headquarters AS studio_hq,
    COUNT(b.title) AS total_blockbusters,
    ROUND(AVG(b.imdb_rating), 2) AS avg_imdb_rating,
    MIN(s.founded_year) AS oldest_studio_founded
FROM blockbusters b
INNER JOIN studio_lookup s ON b.studio = s.studio_name
GROUP BY s.headquarters
ORDER BY total_blockbusters DESC;
"
aggregated_results <- dbGetQuery(con, join_query)
print(aggregated_results)

# Load full blockbuster dataset from DB for cleaning and modeling
db_movies <- dbGetQuery(con, "SELECT * FROM blockbusters;")
dbDisconnect(con)
cat("\n[DB] Disconnected successfully.\n\n")

# 5. DATA CLEANING PIPELINE
cat("--- STARTING DATA CLEANING ---\n")

# A. Convert worldwide gross from character to numeric
clean_gross <- function(gross_str) {
  gross_clean <- gsub("[\\$, ]", "", gross_str)
  return(as.numeric(gross_clean))
}
db_movies$worldwide_gross_numeric <- clean_gross(db_movies$worldwide_gross)

# B. Handle missing values
db_movies$Genre_2[db_movies$Genre_2 == "" | is.na(db_movies$Genre_2)] <- "None"
db_movies$Genre_3[db_movies$Genre_3 == "" | is.na(db_movies$Genre_3)] <- "None"
db_movies$rating[db_movies$rating == "" | is.na(db_movies$rating)] <- "Not Rated"

# C. Filter out rows with missing core statistics
clean_movies <- db_movies[!is.na(db_movies$imdb_rating) & !is.na(db_movies$length), ]

# D. Remove duplicates
clean_movies <- unique(clean_movies)

# E. Outliers Removal (Using IQR on Movie Length)
q1_len <- quantile(clean_movies$length, 0.25, na.rm = TRUE)
q3_len <- quantile(clean_movies$length, 0.75, na.rm = TRUE)
iqr_len <- q3_len - q1_len
lower_bound <- q1_len - 1.5 * iqr_len
upper_bound <- q3_len + 1.5 * iqr_len

clean_movies_no_outliers <- subset(clean_movies, length >= lower_bound & length <= upper_bound)
cat("Outliers removed. Final clean dataset size:", nrow(clean_movies_no_outliers), "rows.\n\n")

# 6. DATA ANALYSIS AND REGRESSION MODELING
cat("--- DATA ANALYSIS & PATTERN EXPLORATION ---\n")

# A. Evaluate correlations of numeric predictors with IMDb Rating
numeric_cols <- c("length", "year", "worldwide_gross_numeric", "rank_in_year")
correlations <- sapply(numeric_cols, function(col) cor(clean_movies_no_outliers[[col]], clean_movies_no_outliers$imdb_rating, use = "complete.obs"))

cat("Pearson Correlation Coefficients with IMDb Rating:\n")
for (name in names(correlations)) {
  cat(sprintf("  - %s: %.4f\n", name, correlations[name]))
}
cat("\n")

# B. Build a simplified regression model using only predictors with significant impact
# length (p < 0.001) and rank_in_year (p < 0.001) are selected based on correlation and initial diagnostics
linear_model <- lm(imdb_rating ~ length + rank_in_year, data = clean_movies_no_outliers)
model_summary <- summary(linear_model)

cat("Linear Regression Coefficients (Predicting IMDb Rating with Significant Predictors):\n")
print(coef(linear_model))
cat("Model R-squared:", round(model_summary$r.squared, 4), "\n\n")

# Get predictions from the model
clean_movies_no_outliers$predicted_rating <- predict(linear_model)

# C. Compute Model Accuracy / Error Metrics
actuals <- clean_movies_no_outliers$imdb_rating
preds <- clean_movies_no_outliers$predicted_rating

mae <- mean(abs(actuals - preds))
rmse <- sqrt(mean((actuals - preds)^2))
accuracy_05 <- mean(abs(actuals - preds) <= 0.5) * 100
accuracy_10 <- mean(abs(actuals - preds) <= 1.0) * 100

cat("Model Evaluation and Accuracy Metrics:\n")
cat(sprintf("  - Mean Absolute Error (MAE): %.4f\n", mae))
cat(sprintf("  - Root Mean Squared Error (RMSE): %.4f\n", rmse))
cat(sprintf("  - Accuracy (Predictions within +/- 0.5 points): %.2f%%\n", accuracy_05))
cat(sprintf("  - Accuracy (Predictions within +/- 1.0 points): %.2f%%\n\n", accuracy_10))

# 7. DATA VISUALIZATION (Comprehensive 2x2 Dashboard)
plot_file <- "blockbuster_analysis.png"
cat("--- GENERATING ANALYSIS DASHBOARD (2x2 Grid) ---\n")
tryCatch({
  png(plot_file, width = 1200, height = 1000)
  
  # Set layout for a 2x2 grid of plots
  par(mfrow = c(2, 2), mar = c(6, 5, 4, 2))
  
  # Plot 1: Correlation of Predictors with IMDb Rating (To identify biggest impact)
  bp <- barplot(correlations, 
                col = c("#56B4E9", "#F0E442", "#009E73", "#D55E00"),
                main = "Pearson Correlation with IMDb Rating",
                ylab = "Correlation Coefficient",
                ylim = c(-0.4, 0.4),
                names.arg = c("Length", "Year", "Gross", "Rank in Year"),
                las = 1)
  abline(h = 0, col = "black")
  # Add value labels
  text(bp, correlations + ifelse(correlations >= 0, 0.02, -0.04), 
       labels = round(correlations, 3), pos = ifelse(correlations >= 0, 3, 1), cex = 1.1)
  
  # Plot 2: Movie Length vs IMDb Rating (Selected Predictor 1)
  plot(clean_movies_no_outliers$length, clean_movies_no_outliers$imdb_rating, 
       col = rgb(0.0, 0.5, 0.0, 0.4), 
       pch = 16,
       main = "Movie Length vs IMDb Rating", 
       xlab = "Length (minutes)", 
       ylab = "IMDb Rating")
  abline(lm(imdb_rating ~ length, data = clean_movies_no_outliers), col = "darkgreen", lwd = 3)
  
  # Plot 3: Rank in Year vs IMDb Rating (Selected Predictor 2)
  plot(clean_movies_no_outliers$rank_in_year, clean_movies_no_outliers$imdb_rating, 
       col = rgb(0.8, 0.2, 0.2, 0.4), 
       pch = 16,
       main = "Rank in Year vs IMDb Rating", 
       xlab = "Rank in Year (1 to 10)", 
       ylab = "IMDb Rating",
       xaxt = "n")
  axis(1, at = 1:10)
  abline(lm(imdb_rating ~ rank_in_year, data = clean_movies_no_outliers), col = "darkred", lwd = 3)
  
  # Plot 4: Actual vs Predicted IMDb Ratings (Model Diagnostic)
  plot(clean_movies_no_outliers$predicted_rating, clean_movies_no_outliers$imdb_rating,
       col = rgb(0.1, 0.4, 0.8, 0.4),
       pch = 16,
       main = "Actual vs Predicted IMDb Ratings",
       xlab = "Predicted IMDb Rating",
       ylab = "Actual IMDb Rating",
       xlim = c(5.5, 8.5),
       ylim = c(4.5, 9.5))
  abline(a = 0, b = 1, col = "black", lty = 2, lwd = 2) # 45-degree reference line
  
  dev.off()
  cat(paste("Successfully saved visualization dashboard to:", plot_file, "\n"))
}, error = function(e) {
  cat("Could not generate plots. Error:", conditionMessage(e), "\n")
})

# 8. ADDITIONAL VISUALIZATION (Studio Gross & Genre Trends)
additional_plot_file <- "studio_genre_trends.png"
cat("--- GENERATING ADDITIONAL VISUALIZATION DASHBOARD ---\n")
tryCatch({
  png(additional_plot_file, width = 1200, height = 600)
  
  # Set layout for side-by-side plots (1 row, 2 columns)
  par(mfrow = c(1, 2), mar = c(8, 6, 4, 2))
  
  # A. Studio Gross Bar Chart
  studio_gross <- aggregate(worldwide_gross_numeric ~ studio, data = clean_movies_no_outliers, FUN = sum)
  studio_gross <- studio_gross[order(-studio_gross$worldwide_gross_numeric), ]
  top_studios <- head(studio_gross, 8)
  gross_billions <- top_studios$worldwide_gross_numeric / 1e9
  
  bp_studio <- barplot(gross_billions,
                       col = rainbow(8, start = 0.5, end = 0.9, alpha = 0.7),
                       main = "Total Worldwide Gross by Studio (Top 8)",
                       ylab = "Total Gross (Billions USD)",
                       ylim = c(0, max(gross_billions) * 1.15),
                       names.arg = top_studios$studio,
                       las = 2,
                       cex.names = 0.8)
  text(bp_studio, gross_billions + 0.5, 
       labels = sprintf("$%.1fB", gross_billions), pos = 3, cex = 0.9)
  
  # B. IMDb Rating of each Genre in every 5 years
  clean_movies_no_outliers$year_bin <- cut(clean_movies_no_outliers$year, 
                                           breaks = seq(1975, 2025, by = 5), 
                                           right = FALSE,
                                           labels = c("1975-1979", "1980-1984", "1985-1989", "1990-1994", "1995-1999", "2000-2004", "2005-2009", "2010-2014", "2015-2019", "2020-2024"))
  
  top_genres_list <- c("Thriller", "Comedy", "Fantasy", "Sci-Fi", "Action")
  genre_trends_data <- clean_movies_no_outliers[clean_movies_no_outliers$Main_Genre %in% top_genres_list, ]
  genre_bin_stats <- aggregate(imdb_rating ~ Main_Genre + year_bin, data = genre_trends_data, FUN = mean)
  
  time_periods <- levels(clean_movies_no_outliers$year_bin)[1:9] # 1975 to 2019
  trend_matrix <- matrix(NA, nrow = length(top_genres_list), ncol = length(time_periods),
                         dimnames = list(top_genres_list, time_periods))
  
  for (g in top_genres_list) {
    for (tp in time_periods) {
      val <- genre_bin_stats$imdb_rating[genre_bin_stats$Main_Genre == g & genre_bin_stats$year_bin == tp]
      if (length(val) > 0) {
        trend_matrix[g, tp] <- val
      }
    }
  }
  
  plot(1:length(time_periods), type = "n", 
       xaxt = "n", 
       xlab = "", 
       ylab = "Average IMDb Rating",
       ylim = c(4.5, 8.5),
       main = "IMDb Rating Trends by Genre (5-Year Bins)")
  
  axis(1, at = 1:length(time_periods), labels = time_periods, las = 2, cex.axis = 0.8)
  
  colors <- c("blue", "red", "purple", "darkgreen", "orange")
  lty_list <- c(1, 2, 3, 4, 5)
  pch_list <- c(15, 16, 17, 18, 19)
  
  for (i in 1:length(top_genres_list)) {
    g <- top_genres_list[i]
    y_vals <- trend_matrix[g, ]
    x_vals <- 1:length(time_periods)
    valid <- !is.na(y_vals)
    lines(x_vals[valid], y_vals[valid], col = colors[i], lty = lty_list[i], lwd = 2)
    points(x_vals[valid], y_vals[valid], col = colors[i], pch = pch_list[i], cex = 1.2)
  }
  
  legend("bottomleft", legend = top_genres_list, col = colors, lty = lty_list, pch = pch_list, 
         bg = "white", cex = 0.8, lwd = 2)
  
  dev.off()
  cat(paste("Successfully saved studio & genre trends to:", additional_plot_file, "\n"))
}, error = function(e) {
  cat("Could not generate additional plots. Error:", conditionMessage(e), "\n")
})

cat("\n=========================================\n")
cat("Pipeline Completed Successfully!\n")
cat("=========================================\n")
