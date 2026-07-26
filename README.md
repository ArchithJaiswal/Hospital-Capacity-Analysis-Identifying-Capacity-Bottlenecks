# Hospital Capacity & Workforce Analytics

**Identifying why Emergency refuses 80.9% of patients despite year-round 100% bed occupancy — and whether it's a capacity problem or a staffing problem.**

An end-to-end data analytics project covering the full pipeline: raw data → Python cleaning → SQL analysis → Power BI dashboard. Built on a year of weekly hospital operations data across four departments (Emergency, Surgery, General Medicine, ICU), ~1,000 patients, and 110 staff.

---

## Tech Stack
`Python (pandas)` · `SQL` · `Power BI (Power Query, DAX)`

---

## The Problem

Hospitals lose patient trust and revenue when demand outpaces bed capacity or staff don't show up. This project quantifies where that's happening, whether the cause is capacity or staffing, and which specific interventions (not just "hire more people") would actually fix it.

---

## Key Findings

| Finding | Detail |
|---|---|
| **Emergency is structurally over capacity** | 100% average occupancy, 80.9% refusal rate — the highest of all four departments by a wide margin |
| **It's a beds problem, not a staffing problem** | Staff attendance is nearly identical across all departments (~59–60%), ruling out staffing as the differentiator for Emergency specifically |
| **Flu season predictably worsens the crisis** | Refusal rate rises to ~88% in Emergency and nearly triples (31%→74%) in General Medicine during flu weeks — a plannable, not just reactive, pattern |
| **ICU has a hidden dependency** | 47% of ICU shifts are covered by off-roster substitute staff, versus 0% in every other department |
| **Ten staff account for a chronic attendance problem** | Identified by name, sitting at 53.8%–55.8% attendance across the full year, spread across all departments and roles |
| **Patient satisfaction is not driven by age, length of stay, or department** | Verified with Pearson correlation (r ≈ 0.07 and r ≈ −0.06) and Power BI's Key Influencers — a deliberately tested and disproven hypothesis, not an assumption |

---

## Pipeline

### 1. Data Cleaning & Feature Engineering (Python / pandas)
- Found and resolved an undocumented ID mismatch: `staff.csv` and `staff_schedule.csv` used completely different, non-overlapping `staff_id` values for the same 110 people. Fixed by joining on staff name instead, which also surfaced 16 off-roster/agency staff never listed in the base roster.
- Engineered `length_of_stay`, `age_group`, `arrival_week` (join key), `is_extended_stay`, and weighted rate columns (`occupancy_rate`, `refusal_rate`, `demand_pressure`).
- Merged staffing and capacity data into a single `weekly_master` table — the base table for all downstream SQL and Power BI work.

### 2. SQL Analysis
- Designed a flat-table schema (deliberately not over-normalized, matched to the actual data shape) with documented primary/composite keys.
- Data quality validation: uniqueness checks, referential checks, range checks, reconciliation checks (all passed cleanly).
- Operational KPIs using window functions (`LAG`, `RANK`), multi-table joins across patient- and weekly-level fact tables, and a manually derived Pearson correlation formula (no built-in `CORR()` assumed, for portability).
- Packaged the final analysis layer into three SQL views for reuse and for direct Power BI consumption.

### 3. Power BI Dashboard
Four report pages:
- **Executive Overview** — KPI cards, refusal rate by department, monthly trend, event filter
- **Capacity & Demand** — occupancy vs. refusal comparison, event-impact matrix, worst-week rankings
- **Patient Experience** — satisfaction by demographic cuts, length-of-stay analysis, Key Influencers validation
- **Workforce Analytics** — attendance and staffing-gap analysis, off-roster reliance, chronic low-attendance staff

Built with 15+ DAX measures using `DIVIDE()`-based weighted rate calculations (not naive column averages), a star-schema relationship model with composite keys, and bookmark-based toggle navigation.

---


## Author
Archith Jaiswal
