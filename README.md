# 🌋 Iron Ore Flotation Process Optimization using Google BigQuery (SQL)

![BigQuery](https://img.shields.io/badge/Google%20BigQuery-34A853?style=for-the-badge&logo=google-bigquery&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-CC292B?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)
![Data Analytics](https://img.shields.io/badge/Data%20Analytics-007ACC?style=for-the-badge)
![Process Engineering](https://img.shields.io/badge/Process%20Engineering-FF9900?style=for-the-badge)

> **"Driving a flotation plant without instant data is like driving a car while only looking at the rearview mirror once an hour."**

---

## 📌 Project Overview
In iron ore froth flotation, **Silica ($SiO_2$)** is the main impurity that must be minimized to ensure high-grade iron concentrate. However, standard industrial practice relies on laboratory chemical assays that introduce a **1 to 1.5-hour time lag**. By the time operators notice a silica spike, tons of off-spec product have already entered the stockpile, leading to severe financial penalties.

This project utilizes **Google BigQuery (SQL)** to perform a comprehensive 5-day analytical audit on historical plant data. By reconstructing the dataset around time lags, operational windows, and human work shifts, this analysis establishes a statistically-backed **"Golden Recipe"** and automated process control baselines to maximize efficiency and minimize quality drops.

* **Dataset:** [Iron Flotation Plant Dataset (Veeralakrishna)](https://www.kaggle.com/veeralakrishna)
* **Core Tools:** Google BigQuery, SQL Window Functions, Statistical Process Control (SPC)

---

## 🚀 Key Analysis & Framework (The 5-Day Journey)

### 📈 Day 1: Time-Series Alignment & Lag Analysis
Simple linear correlations fail because a flotation sircuit is a dynamic system. Using the `LAG()` window function, I aligned the reagent inputs with the delayed laboratory results to find the true reaction timeline.
* **Discovery:** Chemical reagents (Amina & Starch) exhibit their strongest correlation with a **1-Hour Lag**, whereas mechanical adjustments (Air Flow) have an immediate effect on the froth.

```sql
SELECT 
    time_stamp,
    amina_flow,
    LAG(amina_flow, 1) OVER (ORDER BY time_stamp) AS amina_flow_lag1h,
    p_silica_concentrate
FROM `flotation.process`;

```

### 🗺️ Day 2: Operational Mapping & Stability Windows

Using `CASE WHEN` logic, I mapped out the interaction between Pulp pH and Pulp Density to identify where the flotation process remains stable.

* **Discovery:** Amina requires a highly alkaline environment (**pH 9.0–10.0**) to adhere to silica effectively. Operating outside this window causes silica impurities to skyrocket.

### 🕒 Day 3: Shift Work Audit (Uncovering Hidden Realities)

Raw hourly data initially showed a flat line due to artificial data logging habits. By aggregating data around actual **8-hour operational work shifts** (`EXTRACT(HOUR)`), the hidden realities of feed quality fluctuations and shift-to-shift operator habits were exposed.

### 🛡️ Day 4: Statistical Process Control (SPC) Guardrails

To fight alert fatigue and handle gradual process drift, I implemented a **Dynamic 3-Sigma Control Limit** using moving window functions (`AVG` and `STDDEV` across a rolling 60-row window).

* **Impact:** Automated the detection of severe operational upsets (e.g., airflow surging) that break froth stability.

```sql
SELECT 
    time_stamp,
    air_flow,
    AVG(air_flow) OVER(ORDER BY time_stamp ROWS BETWEEN 60 PRECEDING AND CURRENT ROW) AS rolling_avg,
    AVG(air_flow) OVER(ORDER BY time_stamp ROWS BETWEEN 60 PRECEDING AND CURRENT ROW) + 
    (3 * STDDEV(air_flow) OVER(ORDER BY time_stamp ROWS BETWEEN 60 PRECEDING AND CURRENT ROW)) AS UCL
FROM `flotation.process`;

```

### 🎯 Day 5: Prescriptive Analytics & The "Golden Recipe"

By segmenting the data into quality buckets based on silica thresholds, I extracted the exact mechanical and chemical parameters required to consistently secure premium-grade iron.

---

## 📊 The Prescriptive Operational Matrix

The query successfully extracted the plant's **"Sweet Spot"** versus its failure modes:

| Status | Total Hours | Avg. Silica | Avg. Iron | Rec. Amina Flow | Rec. Starch Flow | Total Airflow |
| --- | --- | --- | --- | --- | --- | --- |
| 🟢 **IDEAL** | **495** | **1.64%** | **64.67%** | **481.51** | **3041.52** | **2103.92** |
| 🟡 **WARNING** | 167 | 3.60% | 64.80% | 479.18 | 3032.75 | 2106.87 |
| 🔴 **CRITICAL** | 158 | 4.60% | 64.92% | 480.89 | 3144.29 | 2098.71 |

### 💡 Core Engineering Insights:

1. **The Over-Depression Trap:** In the **CRITICAL** zone, Starch flow spiked to its highest point (**3144.29**). This provides empirical proof of *over-depression*—excessive chemicals disrupt froth selectivity, forcing silica to overflow into the final product instead of floating away.
2. **Standardizing the Target:** To lock in a premium iron grade of **64.67%**, operations must standardize the process at a stable **9.55 pH** and a total airflow rate of **2103**.

---

## 🔮 Next Frontier: Phase 2 (Machine Learning Soft-Sensor)

While historical data auditing via SQL creates solid baseline SOPs, hindsight cannot fully solve a 1-hour lab assay delay.

**The Ultimate Solution:** I am shifting the architecture from **SQL to Python** to build an AI-powered **Soft-Sensor (using XGBoost and LSTM)**. The goal is to predict silica concentrate levels in real-time every 20 seconds, eliminating the reliance on delayed lab data completely.

---

## 👨‍💻 Author

**DiksNeoAnalyst**

* Metallurgical Engineer & Process Data Analyst
* [LinkedIn Profile](https://www.google.com/search?q=https://www.linkedin.com/in/dikrifajar) | [Portfolio Website](https://diksneoanalyst.github.io)

