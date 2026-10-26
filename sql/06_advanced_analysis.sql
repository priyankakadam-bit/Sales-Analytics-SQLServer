/* =============================================================================
   06_advanced_analysis.sql
   New analyses: growth, RFM segments, cohort retention, market basket,
   Pareto 80/20, churn, cancellations, payment behaviour, new vs returning.
   ============================================================================= */
USE SalesDB;
GO

-- 1. Growth: month-over-month %, year-over-year %, running total, 3-month average
WITH m AS (
    SELECT MonthStart, Revenue FROM dbo.vw_MonthlyRevenue
)
SELECT MonthStart,
       Revenue,
       CAST(100.0 * (Revenue - LAG(Revenue) OVER (ORDER BY MonthStart))
            / NULLIF(LAG(Revenue) OVER (ORDER BY MonthStart), 0) AS DECIMAL(6,1))     AS MoMGrowthPct,
       CAST(100.0 * (Revenue - LAG(Revenue, 12) OVER (ORDER BY MonthStart))
            / NULLIF(LAG(Revenue, 12) OVER (ORDER BY MonthStart), 0) AS DECIMAL(6,1)) AS YoYGrowthPct,
       SUM(Revenue) OVER (ORDER BY MonthStart ROWS UNBOUNDED PRECEDING)               AS RunningTotal,
       CAST(AVG(Revenue) OVER (ORDER BY MonthStart
                               ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS DECIMAL(12,2)) AS MovingAvg3M
FROM m
ORDER BY MonthStart;

-- 2. RFM segments: how many customers and how much revenue in each -----------
SELECT Segment,
       COUNT(*)                         AS Customers,
       SUM(Monetary)                    AS Revenue,
       CAST(100.0 * SUM(Monetary) / SUM(SUM(Monetary)) OVER () AS DECIMAL(5,1)) AS RevenueSharePct,
       AVG(RecencyDays)                 AS AvgRecencyDays,
       CAST(AVG(1.0 * Frequency) AS DECIMAL(5,1)) AS AvgOrders
FROM dbo.vw_CustomerRFM
GROUP BY Segment
ORDER BY Revenue DESC;

-- 3. Cohort retention matrix: % of each month's new customers buying again ---
SELECT CohortMonth,
       MAX(CohortSize) AS NewCustomers,
       MAX(CASE WHEN MonthNumber = 1 THEN RetentionPct END) AS M1,
       MAX(CASE WHEN MonthNumber = 2 THEN RetentionPct END) AS M2,
       MAX(CASE WHEN MonthNumber = 3 THEN RetentionPct END) AS M3,
       MAX(CASE WHEN MonthNumber = 4 THEN RetentionPct END) AS M4,
       MAX(CASE WHEN MonthNumber = 5 THEN RetentionPct END) AS M5,
       MAX(CASE WHEN MonthNumber = 6 THEN RetentionPct END) AS M6
FROM dbo.vw_CohortRetention
GROUP BY CohortMonth
ORDER BY CohortMonth;

-- 4. Market basket: products bought together ---------------------------------
--    Support    = share of all orders containing both products
--    Confidence = of the orders with A, the share that also contain B
--    Lift > 1   = bought together more often than chance
WITH items AS (
    SELECT DISTINCT oi.OrderID, oi.ProductID
    FROM dbo.OrderItems AS oi
    JOIN dbo.Orders     AS o ON o.OrderID = oi.OrderID AND o.Status = 'Completed'
),
total AS (SELECT COUNT(DISTINCT OrderID) * 1.0 AS Orders FROM items),
single AS (SELECT ProductID, COUNT(*) * 1.0 AS Orders FROM items GROUP BY ProductID),
pairs AS (
    SELECT a.ProductID AS ProductA, b.ProductID AS ProductB, COUNT(*) * 1.0 AS Together
    FROM items AS a
    JOIN items AS b ON b.OrderID = a.OrderID AND b.ProductID > a.ProductID
    GROUP BY a.ProductID, b.ProductID
)
SELECT TOP (15)
       pa.ProductName AS ProductA,
       pb.ProductName AS ProductB,
       CAST(p.Together AS INT)                                        AS OrdersTogether,
       CAST(100.0 * p.Together / t.Orders AS DECIMAL(5,2))            AS SupportPct,
       CAST(100.0 * p.Together / sa.Orders AS DECIMAL(5,1))           AS ConfidenceAtoBPct,
       CAST(p.Together * t.Orders / (sa.Orders * sb.Orders) AS DECIMAL(6,2)) AS Lift
FROM pairs AS p
CROSS JOIN total AS t
JOIN single AS sa ON sa.ProductID = p.ProductA
JOIN single AS sb ON sb.ProductID = p.ProductB
JOIN dbo.Products AS pa ON pa.ProductID = p.ProductA
JOIN dbo.Products AS pb ON pb.ProductID = p.ProductB
WHERE p.Together >= 20                -- ignore rare pairs
ORDER BY Lift DESC;

-- 5. Pareto (80/20): how concentrated is revenue? -----------------------------
WITH c AS (
    SELECT CustomerID, LifetimeValue AS Revenue
    FROM dbo.vw_CustomerLifetimeValue
    WHERE LifetimeValue > 0
),
r AS (
    SELECT Revenue,
           ROW_NUMBER() OVER (ORDER BY Revenue DESC)                          AS rn,
           COUNT(*)     OVER ()                                               AS Customers,
           SUM(Revenue) OVER ()                                               AS Total,
           SUM(Revenue) OVER (ORDER BY Revenue DESC ROWS UNBOUNDED PRECEDING) AS Cumulative
    FROM c
)
SELECT CAST(100.0 * SUM(CASE WHEN rn <= 0.2 * Customers THEN Revenue END) / MAX(Total) AS DECIMAL(5,1))
           AS RevenueShareOfTop20PctCustomers,
       CAST(100.0 * MIN(CASE WHEN Cumulative >= 0.8 * Total THEN rn END) / MAX(Customers) AS DECIMAL(5,1))
           AS PctOfCustomersFor80PctRevenue
FROM r;

-- 6. Churn: customers with no completed order in the last 90 days -------------
WITH ref AS (SELECT MAX(OrderDate) AS LastDate FROM dbo.Orders WHERE Status = 'Completed')
SELECT v.Country,
       COUNT(*) AS Buyers,
       SUM(CASE WHEN DATEDIFF(DAY, v.LastOrderDate, r.LastDate) > 90 THEN 1 ELSE 0 END) AS Inactive90Days,
       CAST(100.0 * SUM(CASE WHEN DATEDIFF(DAY, v.LastOrderDate, r.LastDate) > 90 THEN 1 ELSE 0 END)
            / COUNT(*) AS DECIMAL(5,1)) AS ChurnRatePct
FROM dbo.vw_CustomerLifetimeValue AS v
CROSS JOIN ref AS r
WHERE v.CompletedOrders > 0
GROUP BY v.Country
ORDER BY ChurnRatePct DESC;

-- 7a. Cancellation rate by month ----------------------------------------------
SELECT DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS MonthStart,
       COUNT(*) AS Orders,
       SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END) AS Cancelled,
       CAST(100.0 * SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS CancelRatePct
FROM dbo.Orders
GROUP BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)
ORDER BY MonthStart;

-- 7b. Cancellation rate by category (an order counts for each category in it) -
SELECT pr.Category,
       COUNT(DISTINCT o.OrderID) AS Orders,
       COUNT(DISTINCT CASE WHEN o.Status = 'Cancelled' THEN o.OrderID END) AS Cancelled,
       CAST(100.0 * COUNT(DISTINCT CASE WHEN o.Status = 'Cancelled' THEN o.OrderID END)
            / COUNT(DISTINCT o.OrderID) AS DECIMAL(5,1)) AS CancelRatePct,
       SUM(CASE WHEN o.Status = 'Cancelled' THEN oi.Quantity * oi.UnitPrice ELSE 0 END) AS LostRevenue
FROM dbo.Orders     AS o
JOIN dbo.OrderItems AS oi ON oi.OrderID = o.OrderID
JOIN dbo.Products   AS pr ON pr.ProductID = oi.ProductID
GROUP BY pr.Category
ORDER BY CancelRatePct DESC;

-- 8. Payment methods: mix, average order and days to pay ----------------------
SELECT p.Method,
       COUNT(*)      AS Payments,
       SUM(p.Amount) AS Revenue,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1))           AS SharePct,
       CAST(AVG(p.Amount) AS DECIMAL(12,2))                                     AS AvgPayment,
       CAST(AVG(1.0 * DATEDIFF(DAY, o.OrderDate, p.PaymentDate)) AS DECIMAL(4,2)) AS AvgDaysToPay
FROM dbo.Payments AS p
JOIN dbo.Orders   AS o ON o.OrderID = p.OrderID
GROUP BY p.Method
ORDER BY Revenue DESC;

-- 9. New vs returning customer revenue per month ------------------------------
SELECT OrderMonth,
       SUM(CASE WHEN IsFirstOrder = 1 THEN PaidAmount ELSE 0 END) AS NewCustomerRevenue,
       SUM(CASE WHEN IsFirstOrder = 0 THEN PaidAmount ELSE 0 END) AS ReturningCustomerRevenue,
       CAST(100.0 * SUM(CASE WHEN IsFirstOrder = 0 THEN PaidAmount ELSE 0 END)
            / SUM(PaidAmount) AS DECIMAL(5,1)) AS ReturningSharePct
FROM dbo.vw_OrderSummary
WHERE Status = 'Completed'
GROUP BY OrderMonth
ORDER BY OrderMonth;

-- 10. Sales by weekday (uses the DimDate calendar) -----------------------------
SELECT d.[DayOfWeek],
       COUNT(*)      AS Orders,
       SUM(p.Amount) AS Revenue,
       CAST(AVG(p.Amount) AS DECIMAL(12,2)) AS AvgOrderValue
FROM dbo.Payments AS p
JOIN dbo.Orders   AS o ON o.OrderID = p.OrderID
JOIN dbo.DimDate  AS d ON d.[Date] = o.OrderDate
GROUP BY d.[DayOfWeek], (DATEPART(WEEKDAY, o.OrderDate) + @@DATEFIRST - 2) % 7
ORDER BY (DATEPART(WEEKDAY, o.OrderDate) + @@DATEFIRST - 2) % 7;   -- Monday first
