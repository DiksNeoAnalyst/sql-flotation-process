-- 1. Analisis Lag Waktu Dampak Reagents terhadap Kualitas Konsentrat

WITH HourlyLagged AS (
  SELECT 
    `p_silica_concentrate` AS silica_target,
    `Amina_Flow` AS amina_current,
    `Starch_Flow` AS starch_current,
    `airflow_col1` AS airflow_current, 
    LAG(`Amina_Flow`, 1) OVER(ORDER BY time_stamp) as amina_lag_1h,
    LAG(`Amina_Flow`, 2) OVER(ORDER BY time_stamp) as amina_lag_2h,
    LAG(`Starch_Flow`, 1) OVER(ORDER BY time_stamp) as starch_lag_1h,
    LAG(`Starch_Flow`, 2) OVER(ORDER BY time_stamp) as starch_lag_2h,
    LAG(`airflow_col1`, 1) OVER(ORDER BY time_stamp) as airflow_lag_1h,
    LAG(`airflow_col1`, 2) OVER(ORDER BY time_stamp) as airflow_lag_2h
  FROM `flotation.process`
)
SELECT 
  ROUND(CORR(silica_target, amina_current), 3) as corr_amina_current,
  ROUND(CORR(silica_target, amina_lag_1h), 3) as corr_amina_1h,
  ROUND(CORR(silica_target, amina_lag_2h), 3) as corr_amina_2h,
  ROUND(CORR(silica_target, starch_current), 3) as corr_starch_current,
  ROUND(CORR(silica_target, starch_lag_1h), 3) as corr_starch_1h,
  ROUND(CORR(silica_target, starch_lag_2h), 3) as corr_starch_2h,
  ROUND(CORR(silica_target, airflow_current), 3) as corr_airflow_current,
  ROUND(CORR(silica_target, airflow_lag_1h), 3) as corr_airflow_1h,
  ROUND(CORR(silica_target, airflow_lag_2h), 3) as corr_airflow_2h,
FROM HourlyLagged;

-- 2. Identifikasi "Ideal Operational Windows" (Klasifikasi Kondisi Stabil vs Upset)

SELECT 
  CASE 
    WHEN `Ore_Pulp_pH` < 9 THEN 'Low pH (<9)'
    WHEN `Ore_Pulp_pH` BETWEEN 9 AND 10 THEN 'Optimal pH (9-10)'
    ELSE 'High pH (>10)'
  END AS ph_zone,
  CASE 
    WHEN `Ore_Pulp_Density` < 1.5 THEN 'Low Density'
    WHEN `Ore_Pulp_Density` BETWEEN 1.5 AND 1.7 THEN 'Optimal Density'
    ELSE 'High Density'
  END AS density_zone,
  COUNT(*) as total_hours_logged,
  ROUND(AVG(`p_silica_concentrate`), 3) as avg_silica_impurity,
  ROUND(AVG(`p_iron_concentrate`), 3) as avg_iron_recovery
FROM `flotation.process`
GROUP BY 1, 2
ORDER BY avg_silica_impurity ASC;

-- 3. Analisis Fluktuasi Kualitas Feed (Karakteristik Ore Berdasarkan Shift)

SELECT 
  EXTRACT(HOUR FROM time_stamp) AS hour_of_day,
  ROUND(AVG(`p_silica_feed`), 2) AS avg_silica_in_feed,
  ROUND(STDDEV_POP(`p_silica_feed`), 2) AS volatility_silica_feed,
  ROUND(AVG(`airflow_col1`), 2) AS avg_air_flow_col1,
  ROUND(AVG(`p_silica_concentrate`), 2) AS avg_silica_in_product
FROM `flotation.process`
GROUP BY 1
ORDER BY 1;

--tweak shift

WITH ShiftData AS (
  SELECT 
    CASE 
      WHEN EXTRACT(HOUR FROM time_stamp) BETWEEN 6 AND 13 THEN 'Morning (06-14)'
      WHEN EXTRACT(HOUR FROM time_stamp) BETWEEN 14 AND 21 THEN 'Evening (14-22)'
      ELSE 'Night (22-06)'
    END AS shift_work,
    `p_silica_feed` AS silica_feed,
    `airflow_col1` AS air_flow,
    `p_silica_concentrate` AS silica_product
  FROM `flotation.process`
)
SELECT 
  shift_work,
  COUNT(*) as total_data_points,
  ROUND(AVG(silica_feed), 2) AS avg_silica_feed,
  ROUND(STDDEV_POP(silica_feed), 2) AS volatility_silica_feed,
  ROUND(AVG(air_flow), 2) AS avg_air_flow,
  ROUND(AVG(silica_product), 2) AS avg_silica_product
FROM ShiftData
GROUP BY 1
ORDER BY shift_work;

-- 4. Deteksi Anomali Sensor Menggunakan Aturan Statistik (Statistical Process Control - SPC)

WITH SPC_Base AS (
  SELECT 
    time_stamp,
    `airflow_col1` AS air_flow,
    AVG(`airflow_col1`) OVER(
      ORDER BY time_stamp ROWS BETWEEN 60 PRECEDING AND CURRENT ROW
    ) as rolling_avg,
    STDDEV(`airflow_col1`) OVER(
      ORDER BY time_stamp ROWS BETWEEN 60 PRECEDING AND CURRENT ROW
    ) as rolling_std
  FROM `flotation.process`
)
SELECT 
  time_stamp,
  air_flow,
  rolling_avg,
  (rolling_avg + 3 * rolling_std) AS UCL,
  (rolling_avg - 3 * rolling_std) AS LCL,
  CASE 
    WHEN air_flow > (rolling_avg + 3 * rolling_std) OR air_flow < (rolling_avg - 3 * rolling_std) 
    THEN 'Out of Control (Anomaly)' 
    ELSE 'Normal' 
  END AS process_status
FROM SPC_Base
WHERE rolling_std > 0
LIMIT 100;

-- 5. Findings Optimal Process

WITH process_status AS (
    -- Langkah 1: Mengkategorikan kondisi operasi berdasarkan batas kualitas silika (Target: < 3% dianggap ideal)
    SELECT 
        *,
        CASE 
            WHEN p_silica_concentrate <= 3.0 THEN 'IDEAL (Low Silica)'
            WHEN p_silica_concentrate BETWEEN 3.01 AND 4.5 THEN 'WARNING (Medium Silica)'
            ELSE 'CRITICAL (High Silica - Penalty)'
        END AS quality_status
    FROM flotation.process
)

-- Langkah 2: Menghitung rata-rata parameter kontrol pada setiap kondisi kualitas untuk mencari "Sweet Spot"
SELECT 
    quality_status,
    COUNT(*) AS total_hours_recorded,
    ROUND(CAST(AVG(p_silica_concentrate) AS NUMERIC), 2) AS mean_silica,
    ROUND(CAST(AVG(p_iron_concentrate) AS NUMERIC), 2) AS mean_iron,
    ROUND(CAST(AVG(Amina_Flow) AS NUMERIC), 2) AS recom_amina_flow,
    ROUND(CAST(AVG(Starch_Flow) AS NUMERIC), 2) AS recom_starch_flow,
    ROUND(CAST(AVG(Ore_Pulp_pH) AS NUMERIC), 2) AS recom_pulp_ph,
    ROUND(CAST(AVG(airflow_col1 + airflow_col2 + airflow_col3 + airflow_col4 + airflow_col5 + airflow_col6 + airflow_col7) AS NUMERIC), 2) AS recom_total_airflow,
    ROUND(CAST(AVG(Amina_Flow + Starch_Flow) AS NUMERIC), 2) AS mean_reagent_combflow
FROM process_status
GROUP BY quality_status
ORDER BY mean_silica ASC;
