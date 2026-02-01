--RFM Feature Table 90 days 
DROP TABLE IF EXISTS rfm_features_90d;

CREATE TABLE rfm_features_90d AS
WITH base AS (
  SELECT
    cl.customer_unique_id,
    cl.as_of_date,
    cl.churn
  FROM churn_labels_fixed cl
),
hist AS (
  SELECT
    b.customer_unique_id,
    b.as_of_date,
    b.churn,
    o.order_id,
    o.order_date
  FROM base b
  LEFT JOIN orders o
    ON b.customer_unique_id = o.customer_unique_id
   AND o.order_date <= b.as_of_date
   AND o.order_date > DATE(b.as_of_date, '-90 day')
)
SELECT
  customer_unique_id,
  as_of_date,
  churn,

  /* R: days since last order within lookback window */
  CASE
    WHEN MAX(order_date) IS NULL THEN NULL
    ELSE CAST(julianday(as_of_date) - julianday(MAX(order_date)) AS INTEGER)
  END AS recency_days,

  /* F: number of orders in last 90d */
  COUNT(DISTINCT order_id) AS frequency_90d,

  /* Optional: active flag (has any order in last 90d) */
  CASE WHEN COUNT(DISTINCT order_id) > 0 THEN 1 ELSE 0 END AS is_active_90d

FROM hist
GROUP BY customer_unique_id, as_of_date, churn;

--Monetary (M) จาก order_items

DROP VIEW IF EXISTS order_value;

CREATE VIEW order_value AS
SELECT
  order_id,
  SUM(price + freight_value) AS order_value
FROM olist_order_items
GROUP BY order_id;


--create RFM Monetary
DROP TABLE IF EXISTS rfm_features_90d_m;

CREATE TABLE rfm_features_90d_m AS
WITH base AS (
  SELECT
    cl.customer_unique_id,
    cl.as_of_date,
    cl.churn
  FROM churn_labels_fixed cl
),
hist AS (
  SELECT
    b.customer_unique_id,
    b.as_of_date,
    b.churn,
    o.order_id,
    o.order_date,
    ov.order_value
  FROM base b
  LEFT JOIN orders o
    ON b.customer_unique_id = o.customer_unique_id
   AND o.order_date <= b.as_of_date
   AND o.order_date > DATE(b.as_of_date, '-90 day')
  LEFT JOIN order_value ov
    ON o.order_id = ov.order_id
)
SELECT
  customer_unique_id,
  as_of_date,
  churn,

  CASE
    WHEN MAX(order_date) IS NULL THEN NULL
    ELSE CAST(julianday(as_of_date) - julianday(MAX(order_date)) AS INTEGER)
  END AS recency_days,

  COUNT(DISTINCT order_id) AS frequency_90d,

  /* M: total spend in last 90d */
  COALESCE(SUM(order_value), 0) AS monetary_90d,

  /* Optional: average order value */
  CASE
    WHEN COUNT(DISTINCT order_id) = 0 THEN NULL
    ELSE SUM(order_value) * 1.0 / COUNT(DISTINCT order_id)
  END AS aov_90d

FROM hist
GROUP BY customer_unique_id, as_of_date, churn;

--จำนวนแถวควรเท่ากับ churn_labels_fixed
SELECT
  (SELECT COUNT(*) FROM churn_labels_fixed) AS n_labels,
  (SELECT COUNT(*) FROM rfm_features_90d_m) AS n_features;

--examples
SELECT *
FROM rfm_features_90d_m
LIMIT 20;

--high recency - high churn
SELECT
  CASE
    WHEN recency_days IS NULL THEN 'no_orders_90d'
    WHEN recency_days <= 7 THEN '0-7'
    WHEN recency_days <= 30 THEN '8-30'
    WHEN recency_days <= 60 THEN '31-60'
    ELSE '61-90'
  END AS recency_bucket,
  COUNT(*) AS rows,
  AVG(churn) AS churn_rate
FROM rfm_features_90d_m
GROUP BY recency_bucket
ORDER BY rows DESC;

