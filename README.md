# Blue Bikes Station Demand Prediction Project
# Midterm Report

**Video Presentation:** [https://youtu.be/9Hh01-UWlYM]

---
## Introduction

This project's goal is to predict daily trip demand at Boston Blue Bikes stations, i.e. estimating how many trips a bluebike station will have on a given date. Ideally, this would help blue bike users plan their trips in advance by knowing which stations will be busy and which won't be. Personally, I've found myself in numerous situations where I planned a trip the night before assuming there would be bikes available at the nearest station, only to wake up the next morning to find none available. This project aims to make bike availability more predictable.

**Hypothesis:** I treat this as a regression problem, predicting daily trip counts based on multiple feature types. Based off personal experience, I believe weather, time(calendar/holidays) and historical trip data would affect trip counts the most, and thus would make the best features. I explore these relationships through visualisations and feature analysis that will be shown in this report.

**Data Sources:** Historical trip data from the Blue Bikes system data portal (https://www.bluebikes.com/system-data), daily weather data from the Open-Meteo Historical Weather API (https://open-meteo.com/en/docs/historical-weather-ap), federal holidays from Python's holidays module, and BU's academic calendar (https://www.bu.edu/reg/calendars/) for academic holiday data.

**Modeling Strategy:** My current plan is to start with a baseline linear regression model to establish benchmark performance, then plan to implement more complex methods (like XGBoost) for the final report to capture non-linear relationships. As of right now, only the linear regression model has been implemented and evaluated.

**Evaluation:** The model is trained on 2022-2024 data and tested on 2025 data to ensure it generalizes to future dates. Performance is measured using RMSE (Root Mean Squared Error), MAE (Mean Absolute Error), and R² (coefficient of determination), as well as directly comparing predicted vs actual resutls.

**Note about final product:** If time permits, I plan to create an interactive web app displaying a map of Boston with clickable stations where users can select a station and future date to see predicted demand.

Anyways, a detailed chronological report of progress below:

---

### 1. Data Collection and Processing

Getting the data ready for modeling turned out to be more complex than expected. Here's what I dealt with:

#### Starting Point: Raw Data Sources
All datasets range from 1-1-2022 to 9-30-2025

**Blue Bikes Trip Data (45 CSV files, Jan 2022 to Sep 2025 inclusive):**
- Individual trip records with start/end times, station IDs, and user types
- Initial Format: One row per trip (15.7M trips total)
- Challenge discovered: CSV format changed mid-way through our data range because bluebikes updated their system in April 2023

**Weather Data (Open-Meteo API):**
- Daily weather observations for Boston coordinates (42.36°N, 71.13°W)
- Variables: temperature (min/max/mean), precipitation, wind speed, snowfall
- Initial Format: One row per day

**Calendar Data (Generated manually using getCalendarFeatures.py):**
- Federal holidays from 2022-2025 (New Year's, MLK Day, Memorial Day, etc.)
- BU Academic calendar breaks (Winter break, Spring break, Summer, Thanksgiving)
- Format: Generated CSV using Python's holidays and pandas modules with `date`, `is_holiday`, `day_of_week`, `is_academic_break` columns

#### Challenge 1: CSV Format Changed Mid-Dataset

When loading the trip files, I discovered Blue Bikes changed their data format in April 2023:

**Old Format (Jan 2022 - Mar 2023):**
```
tripduration,starttime,stoptime,start station id,start station name,usertype
597,"2022-01-01 00:00:25.1660","2022-01-01 00:10:22.1920",178,"MIT Pacific St",Subscriber
```

**New Format (Apr 2023 - Sep 2025):**
```
ride_id,started_at,ended_at,start_station_id,start_station_name,member_casual
"ABC123","2023-04-13 13:49:59","2023-04-13 13:55:10","M32006","MIT at Mass Ave",member
```

**Solution:** Detect which format each file uses and standardize all columns to the new format during loading. This lets me combine all 45 monthly files into one dataset.

#### Challenge 2: Station IDs Changed Too

Not only did the CSV format change, but Blue Bikes also switched their station ID system:
- **Old system:** Numeric IDs (67, 178, 486)
- **New system:** Alphanumeric IDs (M32006, D32016, N32008)

The same physical station location had different IDs in the two periods! For example:
- Historic ID `67` and new ID `M32006` are both "MIT at Mass Ave / Amherst St"
- Historic ID `178` and new ID `M32041` are both "MIT Pacific St at Purrington St"

This caused duplicate counting - we initially saw 627 "unique" stations when there are actually only 608 physical locations.

**Solution:** 
1. Downloaded official Blue Bikes station list which includes a "Station ID (to match to historic system data)" column
2. Created a mapping dictionary from old IDs to new IDs (443 mappings)
3. Converted all old IDs in the trip data to their new equivalents
4. Final result: 608 unique stations correctly identified
Note: the official station list also showed that there were 573 stations still in use, meaning 608-573 = 35 stations no longer in use. 


#### Challenge 3: Station Name Duplicates

Even after ID mapping, some duplicate stations still remained because they were no longer listed in the official station list (out of order). 

**Solution:** For each unique station name, consolidate to a single preferred ID (favoring the new format alphanumeric IDs over numeric ones), then re-aggregate trip counts.

#### Processing Steps
Primarily used pandas Python module for processing and cleaning. See detailed workflow in the process_data.ipynb <br/>
**1. Trip Data Aggregation:**
- Loaded all 45 monthly CSVs with 15.7 million trips (rows)
- Standardized columns and station IDs (challenges faced detailed above)
- Extracted date from timestamps
- Aggregated from individual trips to total trips per station per day
- Result: CSV with 566,622 rows detailing for every date/station pair, how many trips a station had on that date. 

**2. Weather Data Processing:**
- Loaded CSV, skipped metadata rows at the top
- Renamed columns (removed units, simplified names)
- Converted date column to datetime
- Extracted key features: `temp_mean`, `precipitation`, `wind_speed`, `snowfall`
- Result: 1,369 daily weather values

**3. Calendar Features:**
- Created CSV manually with federal holidays (44 days) using getCalendarFeatures.py script
- For academic breaks, used BU academic calendar (599 days across all breaks)
- Included `day_of_week` (0=Monday, 6=Sunday) for each date
- Result: 1,461 days with calendar features

**4. Merging:**
- Started with daily trip counts per station
- Left join weather data on date (all station-day records get same weather)
- Left join calendar features on date
- Added temporal features: `month`, `year` extracted from dates
- Result: Single merged dataset ready for modeling

#### Final Dataset Structure

**Before (Individual Trip Record):**
```
ride_id,started_at,ended_at,start_station_id,start_station_name,member_casual
"ABC123","2025-01-03 20:24:01","2025-01-03 20:28:53","D32000","Cambridge St at Joy St","member"
```

**After (Daily Station Aggregation):**
```
station_id,start_station_name,date,trip_count,lat,lng,temp_mean,precipitation,wind_speed,snowfall,is_holiday,day_of_week,is_academic_break,month,year
"D32000","Cambridge St at Joy St","2025-01-03",45,42.361,-71.065,8.2,2.2,10.2,0.0,0,4,1,1,2025
```

**Final Processed and Cleaned Dataset Specs:**
- **Rows:** 566,622 (station-day combinations)
- **Columns:** 15 features
- **Date Range:** 2022-01-01 to 2025-09-30
- **Stations:** 608 unique locations
- **Total Trips Represented:** 15,767,696

---

### 2. Exploratory Data Analysis (Visualisations and Feature Analysis)

Now that I had clean data, I wanted to understand what actually drives bike demand so I could determine if the features I chose were actually relevant. I did this by creating lots of visualisations and doing correlation analysis with the features in the processed dataset.

**Usage Patterns: Day of Week × Month**

![Day of Week vs Month Heatmap](visualizations/day_week_month_heatmap.png)

This heatmap reveals peak usage times across the entire system. The darkest cells show the busiest combinations:
- **Peak period:** Weekdays (Mon-Fri) in summer/fall months (June-September)
- **Lowest period:** Weekends in winter months (December-February)
- **Key insight:** September weekdays are the absolute peak (likely due to university students returning + still-warm weather)

The heatmap confirms that both temporal factors (day of week AND month) matter simultaneously.

**Geographic Distribution:**

![Station Activity Map](visualizations/station_activity_map.png)

The busiest stations cluster around MIT, Harvard, and Central Square - university areas with high commuter traffic. The top station (MIT at Mass Ave) averages 229 daily trips, while smaller suburban stations see around 5 trips per day.

**Case Study: MIT Station**

I picked the busiest station to examine patterns in detail:

![MIT Station Analysis](visualizations/case_study_station.png)

This four-panel view shows:
- **Top-left:** Clear seasonality over time (summer peaks, winter valleys)
- **Top-right:** Strong positive temperature correlation (warmer = more trips)
- **Bottom-left:** Weekdays are consistently busier than weekends
- **Bottom-right:** September is the peak month (likely students returning)

Do these patterns hold across all 608 stations? Let's check:

![System-Wide Analysis](visualizations/system_wide_analysis.png)

This system-wide view aggregates all stations and shows:
- **Top-left:** Same seasonal pattern (system-wide ridership peaks in summer)
- **Top-right:** Temperature correlation holds at system level (warmer weather = more total trips)
- **Bottom-left:** Weekday pattern confirmed (Thursdays and Fridays are busiest system-wide)
- **Bottom-right:** September peak appears across entire network (not just MIT)

**Comparison:**

| Metric | MIT Station | System-Wide Average |
|--------|-------------|---------------------|
| Average daily trips | 229.0 | 27.8 per station |
| Peak day of week | Friday | Friday |
| Peak month | September | September |
| Weekday/Weekend ratio | 1.15x | 1.11x |

The patterns at MIT station match system-wide trends, suggesting my findings generalize across the network. MIT is just a higher-volume version of the typical pattern. This is promising, as it means fitting a model to system wide data might make sense.

**Feature Correlation Analysis:**

![Feature Correlations](visualizations/feature_correlations.png)

**Linear correlations with trip count:**
- **Temperature** (r=0.21): Strongest positive predictor
- **Month** (r=0.13): Seasonal effect
- **Precipitation** (r=-0.08): Negative impact
- **Snowfall** (r=-0.07): Negative impact
- **Day of week** (r=-0.01): Surprisingly weak linear correlation

Some of these correlations seem weak, but that's because they're measuring *linear* relationships. Let's look at the actual patterns:

![Feature Scatter Grid](visualizations/feature_scatter_grid.png)

This grid shows how each feature relates to trip counts:
- **Temperature:** Clear positive relationship (not perfectly linear - optimal range exists)
- **Precipitation:** Non-linear decay (exponential drop-off with heavy rain)
- **Wind/Snow:** Negative relationships but lots of scatter
- **Day of week:** Categorical pattern (can't be captured by linear correlation)
- **Month:** Categorical seasonality (peaks in summer months)

**Non-Linear and Categorical Relationships:**

![Feature Relationships - Categorical](visualizations/feature_relationships_categorical.png)

This view better captures the true relationships:
- **Precipitation bins:** Shows exponential decay - heavy rain (10+ mm) reduces trips by ~45%
- **Temperature bins:** Optimal range 15-25°C for maximum ridership
- **Day of week:** Weekdays consistently higher than weekends (this pattern was hidden in the weak r=-0.01 correlation!)
- **Month:** Clear seasonal pattern with September peak
- **Holidays:** Reduce trips by ~24%
- **Academic breaks:** Reduce trips by ~25%

**Key Finding:** Linear correlation coefficients underestimate the true predictive power of categorical and non-linear features. Day of week and month have strong effects that aren't captured by simple correlation.

**Summary of Feature Effects:**
- **Temperature:** Strong positive effect (r=0.21), optimal range 15-25°C
- **Precipitation:** Exponential negative impact (~45% drop in heavy rain)
- **Seasonality:** 60% higher ridership in summer vs winter
- **Day of week:** 11% higher on weekdays (hidden by weak correlation)
- **Holidays/breaks:** ~24-25% reduction in ridership

---

---

### 3. Modeling So far

**Model Choice:** Linear Regression (baseline)

I started with a simple linear regression model as a baseline. This gives me a benchmark to beat with more complex models later. You can see my detailed process in the linear_modeling.ipynb.

**Features Used:**

I included 9 input features that I thought most important based off the data exploration I conducted bfore:
- **Weather (4 features):** `temp_mean`, `precipitation`, `wind_speed`, `snowfall`
- **Temporal (3 features):** `day_of_week`, `month`, `is_academic_break`
- **Calendar (1 feature):** `is_holiday`
- **Location (1 feature):** `station_id` (one-hot encoded into 539 dummy variables)

**Why Station ID?**

This was a critical decision. Different stations have vastly different baseline demand - MIT averages 229 trips/day while small stations see 5 trips/day. 

I tested the model both ways:
- **Without station_id:** R² = 0.048 (basically useless) (NOTE: the jupyter notebook doesn't show this one because I replaced it with the station_id inclusive model)
- **With station_id:** R² = 0.731 (captures 73% of variance)

Station location is the single most important predictor. By encoding it, each station gets its own baseline adjustment.

**Train/Test Split:**

- **Train:** 2022-2024 data (432,022 rows)
- **Test:** 2025 data (134,600 rows)

---

### 4. Preliminary Results
**Evaluation Approach:**

To evaluate our model, we use three standard regression metrics on both training (2022-2024) and test (2025) sets:
- **RMSE (Root Mean Squared Error):** Measures average prediction error, penalizing large errors more heavily. Useful for understanding worst-case performance.
- **MAE (Mean Absolute Error):** Average absolute difference between predicted and actual trips. More interpretable than RMSE - directly tells us "off by X trips on average."
- **R² (Coefficient of Determination):** Proportion of variance explained by the model (0 = useless, 1 = perfect). Shows how much better the model is than just predicting the mean.

By comparing training vs test performance, we can detect overfitting (model memorizing training data rather than learning generalizable patterns). Similar scores indicate the model generalizes well to future dates.

**Model Performance:**

| Metric | Training | Test |
|--------|----------|------|
| RMSE | 17.69 | 16.74 |
| MAE | 11.02 | 11.67 |
| R² | 0.752 | 0.731 |

**What this means:**
- Model explains 73.1% of variance in daily trip counts (pretty good for a baseline!)
- Average prediction error is ±12 trips
- Test performance nearly matches training (no overfitting)

**Sample Predictions:**

I wanted to see how the actual predicted values fare, so I looked at the model's predictions for the MIT station we did a case study on when analysing features.

| Date | Actual Trips | Predicted | Error |
|------|--------------|-----------|-------|
| 2025-09-19 | 444 | 249 | +195 |
| 2025-09-05 | 434 | 248 | +186 |
| 2025-09-20 | 417 | 243 | +174 |

The model underpredicts these high-traffic days. Here's the full time series:

![Predictions vs Actual](visualizations/predictions_vs_actual.png)

Notice how the predictions (red dashed line) capture the general level but miss the day-to-day spikes and dips. The model is predicting "typical demand" but can't account for unusual events.

**Where the Model Works Well:**
- Median error is only 8.7 trips
- Typical days are predicted accurately
- Captures seasonal trends (predictions rise from winter to fall)
- Generalizes well to 2025 (unseen data)

**Where It Struggles:**
- Can't predict unusual spikes (concerts, events, first day of classes)
- Smooths over day-to-day volatility
- Misses extreme weather impacts (not just linear relationships)

**Feature Impact Analysis:**

We calculated how much each feature actually moves predictions across its full range:

| Feature | Impact |
|---------|--------|
| Temperature | ±59 trips (coldest to hottest days) |
| Precipitation | -34 trips (dry to heavy rain) |
| Month | ±3 trips (January to December) |
| Day of week | ±2 trips (Monday to Sunday) |
| Holidays | -7 trips |
| Academic breaks | -7 trips |

**Surprising finding:** Month and day_of_week have tiny effects (±2-3 trips) even though our EDA showed strong patterns. What's happening?

The station_id feature overshadows most of the temporal features' effects. Each station learns "I'm typically busy/quiet" rather than the model learning "weekdays are busier than weekends" as a general rule. The model knows MIT is a high-traffic station, but it doesn't distinguish Monday vs Saturday at MIT very well.

Essentially: Station ID dominates, leaving other features with small incremental effects.

---

### 5. Next Steps

**The Problem:**

Linear regression with station dummies achieves good overall accuracy (R²=0.731) but has limitations:
- Predictions are smooth; can't capture day-to-day volatility. It may be good for comparing relative demand between stations, but not good for getting exact values.
- Station dummies dominate, making other feature effects hard to interpret
- Assumes linear relationships (even though features like precipitation have exponential decay)

**Proposed Solution: XGBoost**

For the final report, we'll test XGBoost (gradient boosted trees) to address these issues.

**Why trees should work better:**
1. **Station-specific patterns:** Trees can split on station_id first, then learn that *at MIT specifically*, weekdays have 40+ more trips than weekends. Linear regression gives all stations the same 2.5-trip day_of_week coefficient.

2. **Non-linear effects:** Trees naturally capture exponential precipitation decay and optimal temperature ranges without manual feature engineering.

3. **Better volatility capture:** Trees can model complex interactions (e.g., "rainy Monday in January at MIT" gets a different prediction than just adding up individual effects).

**Alternative approach:** Train 608 separate linear models (one per station) so each location gets its own coefficients. Computationally expensive but could work well for high-traffic stations.

**Expected outcome:** R² improvement to 0.75-0.80, better handling of unusual days, more interpretable feature importance at the station level.

---