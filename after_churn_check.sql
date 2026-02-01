----repeat customer
SELECT
  COUNT(DISTINCT customer_unique_id) * 1.0
  / (SELECT COUNT(DISTINCT customer_unique_id) FROM orders)
  AS repeat_customer_ratio
FROM (
  SELECT customer_unique_id
  FROM orders
  GROUP BY customer_unique_id
  HAVING COUNT(*) > 1
);

-----active base
SELECT
  as_of_date,
  COUNT(*) AS active_customers
FROM customer_snapshots_active
GROUP BY as_of_date
ORDER BY as_of_date;

----frequent buyer
SELECT
  cl.churn,
  COUNT(*) AS rows
FROM churn_labels_fixed cl
WHERE cl.customer_unique_id IN (
  SELECT customer_unique_id
  FROM orders
  GROUP BY customer_unique_id
  HAVING COUNT(*) >= 3
)
GROUP BY cl.churn;
