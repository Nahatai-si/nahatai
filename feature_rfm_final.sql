--check All TABLE
SELECT name
FROM sqlite_master
WHERE type='table'
ORDER BY name;

SELECT name
FROM sqlite_master
WHERE type='table' AND name LIKE '%review%';

DROP VIEW IF EXISTS order_review;

CREATE VIEW order_review AS
SELECT
  order_id,
  AVG(review_score) AS avg_review_score
FROM olist_order_reviews_dataset
GROUP BY order_id;

SELECT * FROM order_review LIMIT 5;


-- review per ORDER, later it will be removed
DROP VIEW IF EXISTS order_review;

CREATE VIEW order_review AS
SELECT
  order_id,
  AVG(review_score) AS avg_review_score,
  MAX(review_score) AS max_review_score,
  MIN(review_score) AS min_review_score
FROM olist_order_reviews
GROUP BY order_id;

SELECT sql
FROM sqlite_master
WHERE type='view' AND name='order_review';

--drop order_review, bc it caused an error, but new table will be created again 
DROP VIEW IF EXISTS order_review;

CREATE VIEW order_review AS
SELECT
  order_id,
  AVG(review_score) AS avg_review_score,
  MAX(review_score) AS max_review_score,
  MIN(review_score) AS min_review_score
FROM olist_order_reviews_dataset
GROUP BY order_id;

SELECT * FROM order_review LIMIT 5;


--delivery order from order TABLE
DROP VIEW IF EXISTS order_delivery;

CREATE VIEW order_delivery AS
SELECT
  order_id,
  DATE(order_purchase_timestamp) AS purchase_date,
  DATE(order_delivered_customer_date) AS delivered_date,
  DATE(order_estimated_delivery_date) AS estimated_date,

  /* วันส่งจริง - วันซื้อ */
  CASE
    WHEN order_delivered_customer_date IS NULL THEN NULL
    ELSE CAST(julianday(DATE(order_delivered_customer_date)) - julianday(DATE(order_purchase_timestamp)) AS INTEGER)
  END AS delivery_days,

  /* ส่งช้าไหม? (ส่งจริงเกินกำหนด) */
  CASE
    WHEN order_delivered_customer_date IS NULL OR order_estimated_delivery_date IS NULL THEN NULL
    ELSE CAST(julianday(DATE(order_delivered_customer_date)) - julianday(DATE(order_estimated_delivery_date)) AS INTEGER)
  END AS delay_days
FROM olist_orders
WHERE order_status = 'delivered';

--payment per ORDER
DROP VIEW IF EXISTS order_payment;

CREATE VIEW order_payment AS
SELECT
  order_id,
  SUM(payment_value) AS payment_total,
  AVG(payment_installments) AS avg_installments,

  /* one-hot count ต่อ payment type */
  SUM(CASE WHEN payment_type = 'credit_card' THEN 1 ELSE 0 END) AS pay_credit_card_cnt,
  SUM(CASE WHEN payment_type = 'boleto' THEN 1 ELSE 0 END) AS pay_boleto_cnt,
  SUM(CASE WHEN payment_type = 'voucher' THEN 1 ELSE 0 END) AS pay_voucher_cnt,
  SUM(CASE WHEN payment_type = 'debit_card' THEN 1 ELSE 0 END) AS pay_debit_card_cnt,

  COUNT(*) AS payment_records
FROM olist_order_payments
GROUP BY order_id;



--create feature table RFM + Review + Delivery + Payment back in 90 days
DROP TABLE IF EXISTS features_90d_plus_reviews;

CREATE TABLE features_90d_plus_reviews AS
WITH base AS (
  SELECT
    customer_unique_id,
    as_of_date,
    churn
  FROM churn_labels_fixed
),
hist AS (
  SELECT
    b.customer_unique_id,
    b.as_of_date,
    b.churn,
    o.order_id,
    o.order_date,

    ov.order_value,

    d.delivery_days,
    d.delay_days,

    p.payment_total,
    p.avg_installments,
    p.pay_credit_card_cnt,
    p.pay_boleto_cnt,
    p.pay_voucher_cnt,
    p.pay_debit_card_cnt,

    r.avg_review_score
  FROM base b
  LEFT JOIN orders o
    ON b.customer_unique_id = o.customer_unique_id
   AND o.order_date <= b.as_of_date
   AND o.order_date > DATE(b.as_of_date, '-90 day')

  LEFT JOIN order_value ov
    ON o.order_id = ov.order_id

  LEFT JOIN order_delivery d
    ON o.order_id = d.order_id

  LEFT JOIN order_payment p
    ON o.order_id = p.order_id

  LEFT JOIN order_review r
    ON o.order_id = r.order_id
)
SELECT
  customer_unique_id,
  as_of_date,
  churn,

  /* RFM */
  CASE
    WHEN MAX(order_date) IS NULL THEN NULL
    ELSE CAST(julianday(as_of_date) - julianday(MAX(order_date)) AS INTEGER)
  END AS recency_days,

  COUNT(DISTINCT order_id) AS frequency_90d,
  COALESCE(SUM(order_value), 0) AS monetary_90d,

  CASE
    WHEN COUNT(DISTINCT order_id) = 0 THEN NULL
    ELSE SUM(order_value) * 1.0 / COUNT(DISTINCT order_id)
  END AS aov_90d,

  /* Delivery */
  AVG(delivery_days) AS avg_delivery_days_90d,
  AVG(delay_days) AS avg_delay_days_90d,

  CASE
    WHEN COUNT(delay_days) = 0 THEN NULL
    ELSE SUM(CASE WHEN delay_days > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(delay_days)
  END AS pct_late_delivery_90d,

  /* Payments */
  AVG(payment_total) AS avg_payment_total_90d,
  AVG(avg_installments) AS avg_installments_90d,

  CASE
    WHEN COUNT(DISTINCT order_id) = 0 THEN NULL
    ELSE SUM(CASE WHEN pay_credit_card_cnt > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(DISTINCT order_id)
  END AS pct_pay_credit_card_90d,

  CASE
    WHEN COUNT(DISTINCT order_id) = 0 THEN NULL
    ELSE SUM(CASE WHEN pay_boleto_cnt > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(DISTINCT order_id)
  END AS pct_pay_boleto_90d,

  CASE
    WHEN COUNT(DISTINCT order_id) = 0 THEN NULL
    ELSE SUM(CASE WHEN pay_voucher_cnt > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(DISTINCT order_id)
  END AS pct_pay_voucher_90d,

  CASE
    WHEN COUNT(DISTINCT order_id) = 0 THEN NULL
    ELSE SUM(CASE WHEN pay_debit_card_cnt > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(DISTINCT order_id)
  END AS pct_pay_debit_card_90d,

  /* Reviews */
  AVG(avg_review_score) AS avg_review_score_90d,

  CASE
    WHEN COUNT(avg_review_score) = 0 THEN NULL
    ELSE SUM(CASE WHEN avg_review_score <= 2 THEN 1 ELSE 0 END) * 1.0 / COUNT(avg_review_score)
  END AS pct_low_review_90d

FROM hist
GROUP BY customer_unique_id, as_of_date, churn;

--validation_row count should match the churn label
SELECT
  (SELECT COUNT(*) FROM churn_labels_fixed) AS n_labels,
  (SELECT COUNT(*) FROM features_90d_plus_reviews) AS n_features;
  
--quick peek
SELECT * FROM features_90d_plus_reviews LIMIT 10;

-- relationship-- high recency - high churn = right signal
SELECT
  CASE
    WHEN recency_days IS NULL THEN 'no_orders'
    WHEN recency_days <= 7 THEN '0-7'
    WHEN recency_days <= 30 THEN '8-30'
    WHEN recency_days <= 60 THEN '31-60'
    ELSE '61-90'
  END AS recency_bucket,
  COUNT(*) AS rows,
  AVG(churn) AS churn_rate
FROM features_90d_plus_reviews
GROUP BY recency_bucket
ORDER BY rows DESC;
--show that the churn pipeline is doing great - no need to change in churn model

--next build a model in Python
--recency monotonic
--label logic
--feature has a right direction
