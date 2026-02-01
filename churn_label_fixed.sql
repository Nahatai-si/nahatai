DROP TABLE IF EXISTS churn_labels_fixed;

CREATE TABLE churn_labels_fixed AS
SELECT
  cs.customer_unique_id,
  cs.as_of_date,
  CASE WHEN COUNT(o2.order_id) = 0 THEN 1 ELSE 0 END AS churn
FROM customer_snapshots_active cs
LEFT JOIN orders o2
  ON cs.customer_unique_id = o2.customer_unique_id
 AND o2.order_date > cs.as_of_date
 AND o2.order_date <= DATE(cs.as_of_date, '+90 day')
GROUP BY
  cs.customer_unique_id,
  cs.as_of_date;
