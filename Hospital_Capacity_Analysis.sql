use hospital_capacity_analysis;

-- Row & uniqueness sanity
SELECT COUNT(*) AS total, COUNT(DISTINCT patient_id) AS unique_ids FROM patients;
SELECT COUNT(*) AS total, COUNT(DISTINCT staff_id) AS unique_ids FROM staff;

-- Referential sanity: any dates where departure precedes arrival?
SELECT COUNT(*) FROM patients WHERE departure_date < arrival_date;

-- Range sanity on ratios (should be 0-1)
SELECT MIN(occupancy_rate), MAX(occupancy_rate),
       MIN(attendance_rate), MAX(attendance_rate)
FROM weekly_master;

-- Reconciliation check: does admitted + refused always equal requested?
SELECT COUNT(*) FROM weekly_master
WHERE patients_admitted + patients_refused <> patients_request;

-- Occupancy & refusal by department
SELECT service,
       ROUND(AVG(occupancy_rate), 3) AS avg_occupancy,
       ROUND(AVG(refusal_rate), 3)   AS avg_refusal_rate,
       SUM(patients_refused)         AS total_refused,
       SUM(patients_request)         AS total_requested
FROM weekly_master
GROUP BY service
ORDER BY avg_refusal_rate DESC;

--  Month-over-month trend of refusal_rate

select service,month, round(avg(refusal_rate),3) as avg_refusal_rate,
        round(avg(refusal_rate) - lag(avg(refusal_rate)) over(partition by service order by month),3) as mom_change
from weekly_master
group by service,month
order by service,month;

-- Event impact on refusal rate & morale

SELECT service, event,
       ROUND(AVG(refusal_rate), 3) AS avg_refusal_rate,
       ROUND(AVG(staff_morale), 1) AS avg_staff_morale,
       COUNT(*) AS weeks_observed
FROM weekly_master
GROUP BY service, event
ORDER BY service, avg_refusal_rate DESC;

-- Top 3 worst weeks per department

select service,week,refusal_rate,patients_request,patients_refused
from ( select service,week,refusal_rate,patients_request,patients_refused,
       rank() over(partition by service order by refusal_rate desc) as rnk
from weekly_master) ranked
where rnk <= 3
order by service,rnk;

-- Attendance vs refusal 

SELECT service,
       ROUND(AVG(attendance_rate), 3) AS avg_staff_attendance,
       ROUND(AVG(refusal_rate), 3)    AS avg_refusal_rate
FROM weekly_master
GROUP BY service;

-- Satisfaction by department

SELECT service, COUNT(*) AS no_of_treatments,
       ROUND(AVG(satisfaction), 2) AS avg_satisfaction,
       MIN(satisfaction) AS min_sat, MAX(satisfaction) AS max_sat
FROM patients
GROUP BY service
ORDER BY avg_satisfaction;

-- Satisfaction by age group

SELECT age_group, COUNT(*) AS n,
       ROUND(AVG(satisfaction), 2) AS avg_satisfaction,
       ROUND(AVG(length_of_stay), 2) AS avg_los
FROM patients
GROUP BY age_group
ORDER BY avg_satisfaction;

-- Does a longer stay hurt satisfaction?

SELECT is_extended_stay,
       ROUND(AVG(satisfaction), 2) AS avg_satisfaction,
       ROUND(AVG(length_of_stay), 2) AS avg_los,
       COUNT(*) AS no_of_patients
FROM patients
GROUP BY is_extended_stay;

-- patient satisfaction based on length of stay

SELECT CASE
         WHEN length_of_stay <= 2 THEN '0-2 days'
         WHEN length_of_stay <= 5 THEN '3-5 days'
         WHEN length_of_stay <= 10 THEN '6-10 days'
         ELSE '10+ days'
       END AS los_bucket,
       ROUND(AVG(satisfaction), 2) AS avg_satisfaction,
       COUNT(*) AS no_of_patients
FROM patients
GROUP BY los_bucket
ORDER BY MIN(length_of_stay);

-- Correlation

SELECT
  (COUNT(*) * SUM(length_of_stay * satisfaction) - SUM(length_of_stay) * SUM(satisfaction))
  /
  ( SQRT(COUNT(*) * SUM(length_of_stay*length_of_stay) - SUM(length_of_stay)*SUM(length_of_stay))
  * SQRT(COUNT(*) * SUM(satisfaction*satisfaction) - SUM(satisfaction)*SUM(satisfaction)) )
  AS pearson_r_los_satisfaction
FROM patients;

-- Monthly satisfaction trend

SELECT arrival_month, ROUND(AVG(satisfaction), 2) AS avg_satisfaction, COUNT(*) AS no_of_patients
FROM patients
GROUP BY arrival_month
ORDER BY arrival_month;

--  patient satisfaction against concurrent staff morale and events

SELECT p.service, wm.event,
       ROUND(AVG(p.satisfaction), 2) AS avg_patient_satisfaction,
       ROUND(AVG(wm.staff_morale), 1) AS avg_staff_morale,
       COUNT(*) AS no_of_patients
FROM patients p
JOIN weekly_master wm
  ON wm.week = p.arrival_week AND wm.service = p.service
GROUP BY p.service, wm.event
ORDER BY p.service, avg_patient_satisfaction;

--  Staffing headcount by role and department

SELECT service, role, COUNT(*) AS headcount
FROM staff
GROUP BY service, role
ORDER BY service, role;

-- Attendance rate by role and department

SELECT role, ROUND(AVG(CAST(present AS FLOAT)), 3) AS attendance_rate, COUNT(*) AS shifts
FROM staff_schedule
GROUP BY role
ORDER BY attendance_rate;

SELECT service, ROUND(AVG(CAST(present AS FLOAT)), 3) AS attendance_rate, COUNT(*) AS shifts
FROM staff_schedule
GROUP BY service
ORDER BY attendance_rate;

-- staffing gap

SELECT service,
       ROUND(AVG(staff_scheduled), 1) AS avg_scheduled,
       ROUND(AVG(staff_present), 1)  AS avg_present,
       ROUND(AVG(staff_scheduled - staff_present), 2) AS avg_headcount_gap
FROM weekly_master
GROUP BY service
ORDER BY avg_headcount_gap DESC;

-- Chronic low-attendance staff 

SELECT staff_id, staff_name, role, service,
       ROUND(AVG(CAST(present AS FLOAT)), 3) AS attendance_rate,
       COUNT(*) AS weeks_tracked
FROM staff_schedule
GROUP BY staff_id, staff_name, role, service
HAVING AVG(CAST(present AS FLOAT)) < 0.56
ORDER BY attendance_rate ASC;

-- Does low attendance actually cause more refusals?

SELECT service,
       CASE WHEN attendance_rate < 0.50 THEN 'low (<50%)'
            WHEN attendance_rate < 0.65 THEN 'mid (50-65%)'
            ELSE 'high (65%+)' END AS attendance_bucket,
       ROUND(AVG(refusal_rate), 3) AS avg_refusal_rate,
       COUNT(*) AS weeks
FROM weekly_master
GROUP BY service, attendance_bucket
ORDER BY service, attendance_bucket;

-- VIEWS

CREATE VIEW vw_department_kpis AS
SELECT service,
       ROUND(AVG(occupancy_rate), 3) AS avg_occupancy,
       ROUND(AVG(refusal_rate), 3)   AS avg_refusal_rate,
       ROUND(AVG(attendance_rate), 3) AS avg_attendance_rate,
       SUM(patients_refused) AS total_refused,
       SUM(patients_request) AS total_requested
FROM weekly_master
GROUP BY service;

CREATE VIEW vw_monthly_trends AS
SELECT service, month,
       ROUND(AVG(occupancy_rate), 3) AS avg_occupancy,
       ROUND(AVG(refusal_rate), 3)   AS avg_refusal_rate,
       ROUND(AVG(patient_satisfaction), 1) AS avg_satisfaction,
       ROUND(AVG(staff_morale), 1) AS avg_staff_morale
FROM weekly_master
GROUP BY service, month;

CREATE VIEW vw_patient_experience AS
SELECT p.patient_id, p.service, p.age_group, p.satisfaction,
       p.length_of_stay, p.is_extended_stay, p.arrival_month, wm.event
FROM patients p
JOIN weekly_master wm ON wm.week = p.arrival_week AND wm.service = p.service;
