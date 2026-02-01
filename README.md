olist-churn-analysis/
│
├── README.md
├── sql/
│   ├── 01_churn_label_fixed.sql
│   ├── 02_frm_query.sql
│   └── 03_after_churn_check.sql
    └── 04.feature_rfm_final.sql
│
└── notebooks/
    └── churn_model_olist.ipynb

📌 Project Title

Churn Analysis & Retention Insights for E-commerce Marketplace (Olist)

📌 Project Overview

This project builds an end-to-end churn analysis pipeline for an e-commerce marketplace using SQL and Python.
The goal is not only to predict churn, but to evaluate whether churn modeling is suitable for a marketplace with a high proportion of one-time buyers.

📌 Business Problem

E-commerce companies aim to retain customers by identifying those at risk of churn.
However, in marketplace businesses, customer behavior is often dominated by one-time purchases, which challenges traditional churn modeling approaches.

This project investigates:

Whether churn prediction is feasible

What insights can be derived from customer behavior

What alternative strategies may provide more business value

📌 Dataset

Olist Brazilian E-commerce Dataset, Source: Kaggle

Tables used: orders, customers, order_items, payments, delivery dates, reviews

(Dataset not included in this repository due to size.)

Methodology
1️.Churn Definition (SQL)

Churn is defined as no purchase within 90 days after a given as-of date

Monthly as-of snapshots are used to simulate real-world prediction

All labels are created using future data relative to each snapshot to avoid data leakage

2️. SQL Data Pipeline

All data preparation is done in SQL (SQLite):

Customer snapshots (active base)

Churn labels (0/1)

Feature engineering with a 90-day lookback:

RFM (recency, frequency, monetary)

Delivery behavior (delivery time, late delivery ratio)

Payment behavior (payment types, installments)

Customer reviews (average score, low-review ratio)

This produces a final Analytical Base Table (ABT) used for modeling.

3️. Exploratory Validation

Key observations:

Overall churn rate ≈ 99%

Repeat customers ≈ 30%

Recency shows a monotonic relationship with churn

The high churn rate is validated as a business reality, not a data or modeling error.

4️. Modeling (Python)

Logistic Regression with class imbalance handling

Focus on ranking metrics, not accuracy:

ROC-AUC ≈ 0.59

Lift@Top10% ≈ 1.00

Modeling Process

1.Load ABT

2.Train logistic regression

3.Evaluate AUC + Lift@Top10%

4.Feature importance

Built an end-to-end churn analysis pipeline for an e-commerce marketplace using SQL and Python. Designed leakage-safe churn labels with as-of date snapshots, engineered behavioral features (RFM, delivery, payments, reviews), and trained a logistic regression model focused on ranking performance. Due to the dominance of one-time buyers, the model showed limited lift, leading to the key insight that traditional churn modeling is not suitable for this business. Recommended reframing the problem toward second-purchase prediction and early lifecycle retention strategies.

📌 Key Insights

Traditional churn modeling provides limited lift in a marketplace dominated by one-time buyers

Behavioral signals exist but are weakly separable

Retention strategies should focus on early lifecycle behavior, not late-stage churn prediction

📌 Business Recommendation

Reframe the problem from churn prediction to:

Predicting whether a customer will make a second purchase within the first 90 days

This aligns better with marketplace economics and offers clearer actionable value.

📌 Tech Stack

SQL (SQLite)
Python (pandas, scikit-learn), Google Colab
