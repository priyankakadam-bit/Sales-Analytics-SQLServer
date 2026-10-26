/* =============================================================================
   04_views.sql
   Reusable views - also the tables to load into Power BI.

   Revenue rule used everywhere: only COMPLETED orders count as revenue.
   (Payments exist only for completed orders, so Payments.Amount and the
    OrderItems totals of completed orders always give the same number.)

   Every CREATE VIEW needs its own batch, hence the GO lines.
   ============================================================================= */
USE SalesDB;
GO

/* One row per order - the main fact table for Power BI */
CREATE OR ALTER VIEW dbo.vw_OrderSummary AS
SELECT o.OrderID,
       o.CustomerID,
       c.Country,
       o.OrderDate,
       DATEFROMPARTS(YEAR(o.OrderDate), MONTH(o.OrderDate), 1) AS OrderMonth,
       o.Status,
       t.ItemLines,
       t.Units,
       t.OrderTotal,
       p.Amount      AS PaidAmount,
       p.PaymentDate,
       p.Method      AS PaymentMethod,
       DATEDIFF(DAY, o.OrderDate, p.PaymentDate) AS DaysToPay,
       -- 1 = this is the customer's first completed order
       CASE WHEN o.Status = 'Completed'
             AND o.OrderID = (SELECT TOP (1) o2.OrderID
                              FROM dbo.Orders AS o2
                              WHERE o2.CustomerID = o.CustomerID AND o2.Status = 'Completed'
                              ORDER BY o2.OrderDate, o2.OrderID)
            THEN 1 ELSE 0 END AS IsFirstOrder
FROM dbo.Orders AS o
JOIN dbo.Customers AS c ON c.CustomerID = o.CustomerID
JOIN (SELECT OrderID,
             COUNT(*)                    AS ItemLines,
             SUM(Quantity)               AS Units,
             SUM(Quantity * UnitPrice)   AS OrderTotal
      FROM dbo.OrderItems
      GROUP BY OrderID) AS t ON t.OrderID = o.OrderID
LEFT JOIN dbo.Payments AS p ON p.OrderID = o.OrderID;
GO

/* Monthly KPIs */
CREATE OR ALTER VIEW dbo.vw_MonthlyRevenue AS
SELECT DATEFROMPARTS(YEAR(p.PaymentDate), MONTH(p.PaymentDate), 1) AS MonthStart,
       SUM(p.Amount)                 AS Revenue,
       COUNT(*)                      AS Orders,
       COUNT(DISTINCT o.CustomerID)  AS ActiveCustomers,
       CAST(AVG(p.Amount) AS DECIMAL(12,2)) AS AvgOrderValue
FROM dbo.Payments AS p
JOIN dbo.Orders   AS o ON o.OrderID = p.OrderID
GROUP BY DATEFROMPARTS(YEAR(p.PaymentDate), MONTH(p.PaymentDate), 1);
GO

/* Customer lifetime value - grouped by CustomerID, not by name */
CREATE OR ALTER VIEW dbo.vw_CustomerLifetimeValue AS
SELECT c.CustomerID,
       c.FullName,
       c.Country,
       c.CreatedAt,
       COUNT(p.PaymentID)        AS CompletedOrders,
       ISNULL(SUM(p.Amount), 0)  AS LifetimeValue,
       MIN(o.OrderDate)          AS FirstOrderDate,
       MAX(o.OrderDate)          AS LastOrderDate
FROM dbo.Customers AS c
LEFT JOIN dbo.Orders   AS o ON o.CustomerID = c.CustomerID AND o.Status = 'Completed'
LEFT JOIN dbo.Payments AS p ON p.OrderID = o.OrderID
GROUP BY c.CustomerID, c.FullName, c.Country, c.CreatedAt;
GO

/* Category revenue (completed orders only) */
CREATE OR ALTER VIEW dbo.vw_CategoryRevenue AS
SELECT pr.Category,
       SUM(oi.Quantity * oi.UnitPrice) AS Revenue,
       SUM(oi.Quantity)                AS UnitsSold,
       COUNT(DISTINCT oi.OrderID)      AS Orders
FROM dbo.OrderItems AS oi
JOIN dbo.Orders     AS o  ON o.OrderID = oi.OrderID AND o.Status = 'Completed'
JOIN dbo.Products   AS pr ON pr.ProductID = oi.ProductID
GROUP BY pr.Category;
GO

/* RFM segmentation: Recency, Frequency, Monetary scored 1-5 */
CREATE OR ALTER VIEW dbo.vw_CustomerRFM AS
WITH ref AS (
    -- the day after the last order in the data (data is historical, so not GETDATE())
    SELECT DATEADD(DAY, 1, MAX(OrderDate)) AS RefDate
    FROM dbo.Orders WHERE Status = 'Completed'
),
base AS (
    SELECT o.CustomerID,
           DATEDIFF(DAY, MAX(o.OrderDate), MAX(r.RefDate)) AS RecencyDays,
           COUNT(*)      AS Frequency,
           SUM(p.Amount) AS Monetary
    FROM dbo.Orders   AS o
    JOIN dbo.Payments AS p ON p.OrderID = o.OrderID
    CROSS JOIN ref    AS r
    WHERE o.Status = 'Completed'
    GROUP BY o.CustomerID
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY RecencyDays DESC) AS R,   -- 5 = bought most recently
           NTILE(5) OVER (ORDER BY Frequency  ASC)   AS F,   -- 5 = buys most often
           NTILE(5) OVER (ORDER BY Monetary   ASC)   AS M    -- 5 = spends the most
    FROM base
)
SELECT s.CustomerID,
       c.FullName,
       c.Country,
       s.RecencyDays, s.Frequency, s.Monetary,
       s.R, s.F, s.M,
       CONCAT(s.R, s.F, s.M) AS RFMScore,
       CASE WHEN s.R >= 4 AND s.F >= 4 AND s.M >= 4 THEN 'Champions'
            WHEN s.R >= 3 AND s.F >= 3               THEN 'Loyal Customers'
            WHEN s.R >= 4 AND s.F <= 2               THEN 'New / Promising'
            WHEN s.R <= 2 AND s.F >= 3               THEN 'At Risk'
            WHEN s.R <= 2 AND s.F <= 2               THEN 'Lost'
            ELSE 'Need Attention' END AS Segment
FROM scored AS s
JOIN dbo.Customers AS c ON c.CustomerID = s.CustomerID;
GO

/* Cohort retention in long format (Power BI matrix: CohortMonth x MonthNumber) */
CREATE OR ALTER VIEW dbo.vw_CohortRetention AS
WITH firsts AS (
    SELECT CustomerID,
           MIN(DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)) AS CohortMonth
    FROM dbo.Orders
    WHERE Status = 'Completed'
    GROUP BY CustomerID
),
activity AS (
    SELECT DISTINCT CustomerID,
           DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS ActivityMonth
    FROM dbo.Orders
    WHERE Status = 'Completed'
),
counts AS (
    SELECT f.CohortMonth,
           DATEDIFF(MONTH, f.CohortMonth, a.ActivityMonth) AS MonthNumber,
           COUNT(*) AS ActiveCustomers
    FROM firsts   AS f
    JOIN activity AS a ON a.CustomerID = f.CustomerID
    GROUP BY f.CohortMonth, DATEDIFF(MONTH, f.CohortMonth, a.ActivityMonth)
)
SELECT c.CohortMonth,
       s.ActiveCustomers AS CohortSize,
       c.MonthNumber,
       c.ActiveCustomers,
       CAST(100.0 * c.ActiveCustomers / s.ActiveCustomers AS DECIMAL(5,1)) AS RetentionPct
FROM counts AS c
JOIN counts AS s ON s.CohortMonth = c.CohortMonth AND s.MonthNumber = 0;
GO
