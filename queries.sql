-- RFM customer segmentation: Online Retail II (UCI)
-- Reference date for recency: 2011-12-10 (day after last purchase)

WITH clean_sales AS (
    SELECT
        s.Invoice,
        s.InvoiceDate,
        CAST(s."Customer ID" AS INTEGER) AS customer_id,
        s.Quantity * s.Price AS revenue
    FROM sales s
    WHERE s."Customer ID" IS NOT NULL
      AND s.Quantity > 0
      AND s.Price > 0
      AND s.Invoice NOT LIKE 'C%'
      AND NOT EXISTS (
          SELECT 1
          FROM sales c
          WHERE c.Invoice LIKE 'C%'
            AND c."Customer ID" = s."Customer ID"
            AND c.StockCode = s.StockCode
            AND c.Quantity = -s.Quantity
            AND c.InvoiceDate >= s.InvoiceDate
      )
),

rfm AS (
    -- One row per customer
    SELECT
        customer_id,
        DATE_DIFF('day', MAX(InvoiceDate), TIMESTAMP '2011-12-10') AS recency,
        COUNT(DISTINCT Invoice) AS frequency,
        ROUND(SUM(revenue), 2) AS monetary
    FROM clean_sales
    GROUP BY customer_id
),

rfm_scores AS (
    -- Score 1-5 on each metric  5 is always best
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency DESC,  customer_id) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC, customer_id) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC,  customer_id) AS m_score
    FROM rfm
)

SELECT
    *,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Potential Loyalists'
        WHEN r_score = 3  AND f_score <= 2 THEN 'Needs Attention'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'Cant Lose Them'
        WHEN r_score <= 2 AND f_score = 3  THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
        ELSE 'Other'
    END AS segment
FROM rfm_scores;
