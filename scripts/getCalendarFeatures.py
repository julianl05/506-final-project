import pandas as pd
import holidays

# Get US federal holidays
us_holidays = holidays.US(years=[2022, 2023, 2024, 2025])

# Create date range
dates = pd.date_range('2022-01-01', '2025-12-31', freq='D')
df = pd.DataFrame({'date': dates})

# Check if each date is a holiday (convert to 0/1)
df['is_holiday'] = df['date'].apply(lambda x: 1 if x in us_holidays else 0)

# Add day of week
df['day_of_week'] = df['date'].dt.dayofweek

# Define academic break periods based on BU academic calendar
academic_breaks = [
    # 2022 - Winter/Summer
    ('2022-01-01', '2022-01-18'),      # Winter break (before Spring 2022 starts Jan 20)
    ('2022-05-05', '2022-09-01'),      # Summer (after Spring ends May 4, before Fall starts Sep 2)
    ('2022-12-19', '2022-12-31'),      # Winter break starts (after Fall exams end Dec 18)
    
    # 2023 - Winter/Spring/Summer
    ('2023-01-01', '2023-01-18'),      # Winter break (before Spring 2023 starts Jan 19)
    ('2023-03-04', '2023-03-12'),      # Spring Recess
    ('2023-05-13', '2023-09-04'),      # Summer (after Spring ends May 12, before Fall starts Sep 5)
    ('2023-12-22', '2023-12-31'),      # Winter break starts (after Fall exams end Dec 21)
    
    # 2024 - Winter/Spring/Summer
    ('2024-01-01', '2024-01-17'),      # Winter break (before Spring 2024 starts Jan 18)
    ('2024-03-09', '2024-03-17'),      # Spring Recess
    ('2024-05-11', '2024-09-02'),      # Summer (after Spring ends May 10, before Fall starts Sep 3)
    ('2024-12-21', '2024-12-31'),      # Winter break starts (after Fall exams end Dec 20)
    
    # 2025 - Winter/Spring/Summer
    ('2025-01-01', '2025-01-20'),      # Winter break (before Spring 2025 starts Jan 21)
    ('2025-03-08', '2025-03-16'),      # Spring Recess
    ('2025-05-10', '2025-09-01'),      # Summer (after Spring ends May 9, before Fall starts Sep 2)
]

# Initialize is_academic_break column
df['is_academic_break'] = 0

# Mark all dates within break periods
for start, end in bu_breaks:
    mask = (df['date'] >= start) & (df['date'] <= end)
    df.loc[mask, 'is_academic_break'] = 1

df.to_csv('data/raw/calendar_features.csv', index=False)

print(f"Created calendar with {len(df)} dates")
print(f"Federal holidays: {df['is_holiday'].sum()}")
print(f"Academic break days: {df['is_academic_break'].sum()}")
print(f"\nSample of break periods:")
print(df[df['is_academic_break'] == 1].head(10))