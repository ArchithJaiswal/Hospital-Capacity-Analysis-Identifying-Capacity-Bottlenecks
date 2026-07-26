"""
STEP 1 — DATA CLEANING & FEATURE ENGINEERING
==============================================
Goal: turn 4 raw CSVs into clean, feature-rich tables that are ready to be
loaded into MySQL for the SQL layer, and ready to feed the prediction models
in step 2 and step 3.

Tables in:
    patients.csv         -> patient-level stays (1 row per patient)
    services_weekly.csv  -> weekly capacity snapshot per department
    staff.csv             -> staff roster (1 row per staff member)
    staff_schedule.csv    -> weekly attendance (1 row per staff per week)

Tables out (in /clean_data/):
    patients_clean.csv
    services_weekly_clean.csv
    staff_clean.csv
    staff_schedule_clean.csv
    weekly_master.csv     <- the single table the prediction models train on
"""

import pandas as pd
import numpy as np
import os

RAW_DIR = "."
OUT_DIR = "clean_data"
os.makedirs(OUT_DIR, exist_ok=True)


# 1. PATIENTS — length of stay, age groups, arrival week (for linking)

patients = pd.read_csv(
    f"{RAW_DIR}/patients.csv",
    parse_dates=["arrival_date", "departure_date"]
)

# Length of stay in days.
patients["length_of_stay"] = (
    patients["departure_date"] - patients["arrival_date"]
).dt.days

# Guard rail: if any stay is 0 or negative, that's a data error worth flagging.
bad_stays = patients[patients["length_of_stay"] <= 0]
if len(bad_stays) > 0:
    print(f"WARNING: {len(bad_stays)} rows have zero/negative length_of_stay")

# Creating Age groups

patients["age_group"] = pd.cut(
    patients["age"],
    bins=[-1, 12, 18, 35, 60, 120],
    labels=["child", "teen", "adult", "middle_age", "senior"]
)

# Week-of-year for arrival — month-of-year for arrival
patients["arrival_week"] = patients["arrival_date"].dt.isocalendar().week
patients["arrival_month"] = patients["arrival_date"].dt.month

# Flag long stays (>75th percentile) 
los_threshold = patients["length_of_stay"].quantile(0.75)
patients["is_extended_stay"] = (patients["length_of_stay"] > los_threshold).astype(int)

patients.to_csv(f"{OUT_DIR}/patients_clean.csv", index=False)
print(f"patients_clean.csv -> {patients.shape[0]} rows, {patients.shape[1]} cols")


# 2. SERVICES WEEKLY — occupancy, refusal rate, demand pressure, events

services = pd.read_csv(f"{RAW_DIR}/services_weekly.csv")

# Core operational ratios. These turn raw counts into rates that are
# comparable across services of different sizes.
services["occupancy_rate"] = (
    services["patients_admitted"] / services["available_beds"]
).round(3)

services["refusal_rate"] = (
    services["patients_refused"] / services["patients_request"]
).round(3)

services["demand_pressure"] = (
    services["patients_request"] / services["available_beds"]
).round(3)

# One-hot encode the 'event' column (none/flu/donation/strike)
event_dummies = pd.get_dummies(services["event"], prefix="event")
services = pd.concat([services, event_dummies], axis=1)

services.to_csv(f"{OUT_DIR}/services_weekly_clean.csv", index=False)
print(f"services_weekly_clean.csv -> {services.shape[0]} rows, {services.shape[1]} cols")


# 3. STAFF ROSTER — passed through, lightly cleaned

staff = pd.read_csv(f"{RAW_DIR}/staff.csv")
staff.to_csv(f"{OUT_DIR}/staff_clean.csv", index=False)
print(f"staff_clean.csv -> {staff.shape[0]} rows, {staff.shape[1]} cols")


# 4. STAFF SCHEDULE 

schedule = pd.read_csv(f"{RAW_DIR}/staff_schedule.csv")

# DATA QUALITY ISSUE FOUND DURING EXPLORATION:
# staff.csv and staff_schedule.csv use DIFFERENT staff_id values for the
# same people (0 overlap on staff_id, full overlap on staff_name).
# staff_schedule.csv also has 126 unique people vs. 110 in staff.csv,
# meaning 16 scheduled staff never appear in the roster file.
# Fix: use staff_name as the reliable join key instead of staff_id.
staff_lookup = staff[["staff_name", "staff_id"]].rename(
    columns={"staff_id": "roster_staff_id"}
)
schedule = schedule.merge(staff_lookup, on="staff_name", how="left")

# Anyone with no match in the roster is a genuine "off-roster" staff member
schedule["is_off_roster"] = schedule["roster_staff_id"].isna().astype(int)

schedule.to_csv(f"{OUT_DIR}/staff_schedule_clean.csv", index=False)
print(f"staff_schedule_clean.csv -> {schedule.shape[0]} rows, {schedule.shape[1]} cols")
print(f"  -> {schedule['is_off_roster'].sum()} off-roster attendance records found")

# Weekly attendance rate per service = staff present / staff scheduled,
# aggregated to (week, service).
attendance = (
    schedule.groupby(["week", "service"])["present"]
    .agg(staff_scheduled="count", staff_present="sum")
    .reset_index()
)
attendance["attendance_rate"] = (
    attendance["staff_present"] / attendance["staff_scheduled"]
).round(3)


# 5. WEEKLY MASTER TABLE

weekly_master = services.merge(attendance, on=["week", "service"], how="left")

weekly_master.to_csv(f"{OUT_DIR}/weekly_master.csv", index=False)
print(f"weekly_master.csv -> {weekly_master.shape[0]} rows, {weekly_master.shape[1]} cols")

print("\nStep 1 complete. Clean tables are in ./clean_data/")
