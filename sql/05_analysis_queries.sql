/* =============================================================================
   05_analysis_queries.sql
   The original 8 business questions, corrected:
   * only COMPLETED orders count as revenue (before, product/category/AOV
     included cancelled orders, so totals did not match Payments)
   * customers are grouped by CustomerID (names are not unique)
   * DATEFROMPARTS instead of FORMAT (FORMAT is slow on big tables)
   ============================================================================= */
USE SalesDB;
GO

-- 1. Monthly revenue trend ----------------------------------------------------
SELECT DATEFROMPARTS(YEAR(PaymentDate), MONTH(PaymentDate), 1) AS MonthStart,
       SUM(Amount) AS TotalRevenue,
       COUNT(*)    AS Orders
FROM dbo.Payments
GROUP BY DATEFROMPARTS(YEAR(PaymentDate), MONTH(PaymentDate), 1)
ORDER BY MonthStart;

-- 2. Top 10 customers by lifetime value ----------------------------------------
SELECT TOP (10)
       c.CustomerID, c.FullName, c.Country,
       COUNT(*)      AS CompletedOrders,
       SUM(p.Amount) AS LifetimeValue
FROM dbo.Customers AS c
JOIN dbo.Orders    AS o ON o.CustomerID = c.CustomerID
JOIN dbo.Payments  AS p ON p.OrderID = o.OrderID
GROUP BY c.CustomerID, c.FullName, c.Country
ORDER BY LifetimeValue DESC;

-- 3. Repeat customers and repeat rate ------------------------------------------
WITH buyers AS (
    SELECT CustomerID, COUNT(*) AS CompletedOrders
    FROM dbo.Orders
    WHERE Status = 'Completed'
    GROUP BY CustomerID
)
SELECT COUNT(*) AS Buyers,
       SUM(CASE WHEN CompletedOrders > 1 THEN 1 ELSE 0 END) AS RepeatCustomers,
       CAST(100.0 * SUM(CASE WHEN CompletedOrders > 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS RepeatRatePct
FROM buyers;

-- 4. Average order value (completed orders) -----------------------------------
SELECT CAST(AVG(Amount) AS DECIMAL(12,2)) AS AvgOrderValue,
       COUNT(*)                            AS CompletedOrders
FROM dbo.Payments;

-- 5. Top 10 products by revenue -----------------------------------------------
SELECT TOP (10)
       pr.ProductID, pr.ProductName, pr.Category,
       SUM(oi.Quantity)                AS UnitsSold,
       SUM(oi.Quantity * oi.UnitPrice) AS Revenue
FROM dbo.OrderItems AS oi
JOIN dbo.Orders     AS o  ON o.OrderID = oi.OrderID AND o.Status = 'Completed'
JOIN dbo.Products   AS pr ON pr.ProductID = oi.ProductID
GROUP BY pr.ProductID, pr.ProductName, pr.Category
ORDER BY Revenue DESC;

-- 6a. Revenue by category with share of total ----------------------------------
SELECT Category, Revenue, UnitsSold,
       CAST(100.0 * Revenue / SUM(Revenue) OVER () AS DECIMAL(5,1)) AS SharePct
FROM dbo.vw_CategoryRevenue
ORDER BY Revenue DESC;

-- 6b. Revenue by country with share of total -----------------------------------
SELECT c.Country,
       COUNT(DISTINCT c.CustomerID) AS Customers,
       SUM(p.Amount)                AS Revenue,
       CAST(100.0 * SUM(p.Amount) / SUM(SUM(p.Amount)) OVER () AS DECIMAL(5,1)) AS SharePct
FROM dbo.Customers AS c
JOIN dbo.Orders    AS o ON o.CustomerID = c.CustomerID
JOIN dbo.Payments  AS p ON p.OrderID = o.OrderID
GROUP BY c.Country
ORDER BY Revenue DESC;

-- 7. New customers per month (cohort sizes) ------------------------------------
--    Full retention analysis: see 06_advanced_analysis.sql
WITH firsts AS (
    SELECT CustomerID,
           MIN(DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)) AS CohortMonth
    FROM dbo.Orders
    WHERE Status = 'Completed'
    GROUP BY CustomerID
)
SELECT CohortMonth, COUNT(*) AS NewCustomers
FROM firsts
GROUP BY CohortMonth
ORDER BY CohortMonth;

-- 8. Customer ranking: overall and within each country -------------------------
SELECT CustomerID, FullName, Country, LifetimeValue,
       RANK()  OVER (ORDER BY LifetimeValue DESC)                      AS OverallRank,
       RANK()  OVER (PARTITION BY Country ORDER BY LifetimeValue DESC) AS RankInCountry,
       NTILE(4) OVER (ORDER BY LifetimeValue DESC)                     AS ValueQuartile   -- 1 = top 25%
FROM dbo.vw_CustomerLifetimeValue
WHERE CompletedOrders > 0
ORDER BY OverallRank;
