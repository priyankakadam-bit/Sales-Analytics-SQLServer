/* =============================================================================
   02_sample_data.sql
   Generates two years (2024-2025) of realistic sales data for an online shop.

   Fixes compared to the first version:
   * Set-based inserts instead of WHILE loops (seconds instead of minutes), and
     no repeated DECLARE @i in one batch (that raised an error).
   * Every random value is created with NEWID() *per row* and stored in a temp
     table first (ABS(CHECKSUM(NEWID()) % n) gives 0..n-1). RAND() without a seed returns the SAME value for every row of
     an INSERT ... SELECT, and calling it twice in one CASE gave a skewed
     70 / 25.5 / 4.5 country split instead of the intended one.
   * Customers only order after they signed up, every order has items,
     UnitPrice comes from the product's list price (with occasional discounts),
     and only completed orders get a payment.
   * Built-in patterns to discover: a growing customer base, a Q4 sales peak,
     loyal repeat buyers, popular products, and products bought together.

   ============================================================================= */
USE SalesDB;
GO

SET NOCOUNT ON;

DECLARE @StartDate DATE = '2024-01-01';
DECLARE @EndDate   DATE = '2025-12-31';
DECLARE @Days      INT  = DATEDIFF(DAY, @StartDate, @EndDate);   -- 730

DECLARE @NumCustomers    INT = 2000;   -- sign-ups
DECLARE @RepeatAttempts  INT = 3500;   -- repeat orders to create (a few fall after the end date and are dropped)
DECLARE @Buyers          INT;

/* ---- 0. Clear old data (child tables first) -------------------------------- */
DELETE FROM dbo.Payments;
DELETE FROM dbo.OrderItems;
DELETE FROM dbo.Orders;
DELETE FROM dbo.Products;
DELETE FROM dbo.Customers;
DELETE FROM dbo.DimDate;

/* ---- 1. Helper: numbers 1..20000 ------------------------------------------- */
DROP TABLE IF EXISTS #Numbers;
SELECT TOP (20000) n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
INTO #Numbers
FROM sys.all_objects AS a
CROSS JOIN sys.all_objects AS b;

/* ---- 2. Calendar ------------------------------------------------------------ */
INSERT INTO dbo.DimDate ([Date], [Year], [Quarter], [Month], MonthName, MonthStart, YearMonth, [DayOfWeek], IsWeekend)
SELECT d.[Date],
       YEAR(d.[Date]),
       DATEPART(QUARTER, d.[Date]),
       MONTH(d.[Date]),
       DATENAME(MONTH, d.[Date]),
       DATEFROMPARTS(YEAR(d.[Date]), MONTH(d.[Date]), 1),
       CONVERT(CHAR(7), d.[Date], 126),
       DATENAME(WEEKDAY, d.[Date]),
       CASE WHEN (DATEPART(WEEKDAY, d.[Date]) + @@DATEFIRST - 1) % 7 IN (0, 6) THEN 1 ELSE 0 END
FROM #Numbers
CROSS APPLY (SELECT DATEADD(DAY, n - 1, @StartDate) AS [Date]) AS d
WHERE n <= @Days + 1;

/* ---- 3. Products (listed from most to least popular) ----------------------- */
INSERT INTO dbo.Products (ProductName, Category, Price)
SELECT ProductName, Category, Price
FROM (VALUES
    ( 1, N'Cotton T-Shirt',          N'Clothing',      19.99),
    ( 2, N'Coffee Maker',            N'Home',          89.00),
    ( 3, N'Bestseller Novel',        N'Books',         14.99),
    ( 4, N'Yoga Mat',                N'Sports',        29.99),
    ( 5, N'Jeans',                   N'Clothing',      59.90),
    ( 6, N'Bed Linen Set',           N'Home',          49.90),
    ( 7, N'Cookbook',                N'Books',         24.99),
    ( 8, N'Smartphone',              N'Electronics',  699.00),
    ( 9, N'Running Shoes',           N'Sports',       119.00),
    (10, N'Wireless Earbuds',        N'Electronics',  129.00),
    (11, N'Hoodie',                  N'Clothing',      44.90),
    (12, N'Table Lamp',              N'Home',          39.90),
    (13, N'Children''s Picture Book',N'Books',         12.99),
    (14, N'Water Bottle',            N'Sports',        14.90),
    (15, N'Phone Case',              N'Electronics',   19.90),
    (16, N'Winter Jacket',           N'Clothing',     149.00),
    (17, N'Coffee Beans 1kg',        N'Home',          18.50),
    (18, N'Laptop',                  N'Electronics', 1099.00),
    (19, N'Self-Help Book',          N'Books',         16.99),
    (20, N'Dumbbell Set',            N'Sports',        79.00),
    (21, N'Laptop Sleeve',           N'Electronics',   29.90),
    (22, N'Sneakers',                N'Clothing',      89.90),
    (23, N'Cookware Set',            N'Home',         129.00),
    (24, N'Science Fiction Novel',   N'Books',         13.99),
    (25, N'Fitness Tracker',         N'Sports',        99.00),
    (26, N'Smartwatch',              N'Electronics',  249.00),
    (27, N'Dress',                   N'Clothing',      69.90),
    (28, N'Throw Blanket',           N'Home',          34.90),
    (29, N'Travel Guide',            N'Books',         22.99),
    (30, N'Tennis Racket',           N'Sports',        89.00),
    (31, N'Bluetooth Speaker',       N'Electronics',   79.00),
    (32, N'Scarf',                   N'Clothing',      24.90),
    (33, N'Vacuum Cleaner',          N'Home',         199.00),
    (34, N'Tablet',                  N'Electronics',  449.00),
    (35, N'History Book',            N'Books',         27.99),
    (36, N'Cycling Helmet',          N'Sports',        59.00),
    (37, N'Socks (5-pack)',          N'Clothing',      12.99),
    (38, N'Plant Pot',               N'Home',          15.90),
    (39, N'Biography',               N'Books',         19.99),
    (40, N'Camping Tent',            N'Sports',       179.00)
) AS v (SortNo, ProductName, Category, Price)
ORDER BY SortNo;

/* ---- 4. Customers ----------------------------------------------------------- */
DROP TABLE IF EXISTS #C;
SELECT n,
       ABS(CHECKSUM(NEWID()) % 100)   AS rCountry,
       ABS(CHECKSUM(NEWID()) % 100)   AS rEarly,
       ABS(CHECKSUM(NEWID()) % 60)    AS rEarlyDay,
       ABS(CHECKSUM(NEWID()) % 10000) AS rSignup
INTO #C
FROM #Numbers
WHERE n <= @NumCustomers;

DROP TABLE IF EXISTS #C2;
SELECT n,
       CASE WHEN rCountry < 40 THEN N'Germany'
            WHEN rCountry < 60 THEN N'France'
            WHEN rCountry < 80 THEN N'UK'
            WHEN rCountry < 90 THEN N'Netherlands'
            ELSE N'Spain' END AS Country,
       CASE WHEN rEarly < 5   -- 5% existing customers at the start
            THEN DATEADD(DAY, rEarlyDay, @StartDate)
            -- POWER(...,0.7) pushes sign-ups later: a growing customer base
            ELSE DATEADD(DAY, CAST(@Days * POWER(rSignup / 10000.0E0, 0.7) AS INT), @StartDate)
       END AS CreatedAt
INTO #C2
FROM #C;

-- CustomerIDs follow sign-up order
INSERT INTO dbo.Customers (FullName, Email, Country, CreatedAt)
SELECT CONCAT(N'Customer ', rn), CONCAT(N'customer', rn, N'@example.com'), Country, CreatedAt
FROM (SELECT Country, CreatedAt, ROW_NUMBER() OVER (ORDER BY CreatedAt, n) AS rn FROM #C2) AS x
ORDER BY rn;

/* ---- 5. Orders -------------------------------------------------------------- */
-- 5a. 85% of customers place a first order within 2 weeks of signing up
DROP TABLE IF EXISTS #B;
SELECT CustomerID,
       CreatedAt,
       ABS(CHECKSUM(NEWID()) % 100) AS rBuy,
       ABS(CHECKSUM(NEWID()) % 14)  AS rFirstGap,
       CHECKSUM(NEWID())            AS rLoyalty
INTO #B
FROM dbo.Customers;

DROP TABLE IF EXISTS #Buyers;
SELECT CustomerID,
       CASE WHEN DATEADD(DAY, rFirstGap, CreatedAt) > @EndDate THEN @EndDate
            ELSE DATEADD(DAY, rFirstGap, CreatedAt) END AS FirstOrderDate,
       ROW_NUMBER() OVER (ORDER BY rLoyalty) AS LoyaltyRank       -- random; low rank = most loyal
INTO #Buyers
FROM #B
WHERE rBuy < 85;

SET @Buyers = (SELECT COUNT(*) FROM #Buyers);

-- 5b. repeat orders: loyal customers come back more often, mostly within months
DROP TABLE IF EXISTS #R;
SELECT n,
       ABS(CHECKSUM(NEWID()) % 10000) AS rCustomer,
       ABS(CHECKSUM(NEWID()) % 10000) AS rGap,
       ABS(CHECKSUM(NEWID()) % 100)   AS rSeason,
       ABS(CHECKSUM(NEWID()) % 47)    AS rSeasonDay,     -- 15 Nov + 0..46 days = up to 31 Dec
       ABS(CHECKSUM(NEWID()) % 100)   AS rSeasonYear
INTO #R
FROM #Numbers
WHERE n <= @RepeatAttempts;

DROP TABLE IF EXISTS #OrderRows;
SELECT x.CustomerID, x.OrderDate, ABS(CHECKSUM(NEWID()) % 100) AS rStatus
INTO #OrderRows
FROM (
    SELECT CustomerID, FirstOrderDate AS OrderDate
    FROM #Buyers

    UNION ALL

    SELECT b.CustomerID, d.OrderDate
    FROM #R AS r
    -- POWER(...,1.5) favours low loyalty ranks -> a core of frequent buyers
    JOIN #Buyers AS b ON b.LoyaltyRank = 1 + CAST(@Buyers * POWER(r.rCustomer / 10000.0E0, 1.5) AS INT)
    CROSS APPLY (
        SELECT DATEADD(DAY, 1 + CAST(365 * POWER(r.rGap / 10000.0E0, 1.5) AS INT), b.FirstOrderDate) AS NormalDate,
               DATEADD(DAY, r.rSeasonDay,
                       DATEFROMPARTS(YEAR(@EndDate) - CASE WHEN r.rSeasonYear < 60 THEN 0 ELSE 1 END, 11, 15)) AS SeasonDate
    ) AS s
    CROSS APPLY (
        -- 12% of repeat orders fall in the holiday peak (15 Nov - 31 Dec)
        SELECT CASE WHEN r.rSeason < 12 AND s.SeasonDate > b.FirstOrderDate THEN s.SeasonDate
                    ELSE s.NormalDate END AS OrderDate
    ) AS d
    WHERE d.OrderDate <= @EndDate
) AS x;

INSERT INTO dbo.Orders (CustomerID, OrderDate, Status)
SELECT CustomerID, OrderDate,
       CASE WHEN rStatus < 88 THEN N'Completed' ELSE N'Cancelled' END
FROM #OrderRows
ORDER BY OrderDate, CustomerID;          -- OrderIDs follow time

/* ---- 6. Order items --------------------------------------------------------- */
DROP TABLE IF EXISTS #OrderSize;
SELECT OrderID, 1 + ABS(CHECKSUM(NEWID()) % 4) AS ItemCount      -- 1-4 lines per order
INTO #OrderSize
FROM dbo.Orders;

DROP TABLE IF EXISTS #Lines;
SELECT s.OrderID,
       ABS(CHECKSUM(NEWID()) % 10000) AS rProduct,
       ABS(CHECKSUM(NEWID()) % 100)   AS rQty,
       ABS(CHECKSUM(NEWID()) % 100)   AS rDiscount
INTO #Lines
FROM #OrderSize AS s
JOIN #Numbers   AS k ON k.n <= s.ItemCount;

DROP TABLE IF EXISTS #ProdRank;
SELECT ProductID, Price, ROW_NUMBER() OVER (ORDER BY ProductID) AS rn, COUNT(*) OVER () AS cnt
INTO #ProdRank
FROM dbo.Products;

INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice)
SELECT OrderID, ProductID, Quantity, UnitPrice
FROM (
    SELECT l.OrderID,
           p.ProductID,
           CASE WHEN l.rQty < 60 THEN 1 WHEN l.rQty < 85 THEN 2 WHEN l.rQty < 95 THEN 3 ELSE 4 END AS Quantity,
           -- 20% of lines get a 10% discount
           CAST(ROUND(p.Price * CASE WHEN l.rDiscount < 20 THEN 0.90 ELSE 1.00 END, 2) AS DECIMAL(10,2)) AS UnitPrice,
           ROW_NUMBER() OVER (PARTITION BY l.OrderID, p.ProductID ORDER BY (SELECT NULL)) AS dup
    FROM #Lines AS l
    JOIN #ProdRank AS p
      -- POWER(...,1.3) favours products at the top of the list (best sellers)
      ON p.rn = 1 + CAST((SELECT MAX(cnt) FROM #ProdRank) * POWER(l.rProduct / 10000.0E0, 1.3) AS INT)
) AS x
WHERE dup = 1;                       -- one line per product per order

/* ---- 7. "Frequently bought together" add-ons -------------------------------- */
DROP TABLE IF EXISTS #Pairs;
CREATE TABLE #Pairs (MainProduct NVARCHAR(100), AddOn NVARCHAR(100), ChancePct INT);
INSERT INTO #Pairs VALUES
    (N'Smartphone',    N'Phone Case',       50),
    (N'Laptop',        N'Laptop Sleeve',    45),
    (N'Coffee Maker',  N'Coffee Beans 1kg', 55),
    (N'Yoga Mat',      N'Water Bottle',     40),
    (N'Running Shoes', N'Socks (5-pack)',   35);

DROP TABLE IF EXISTS #AddOns;
SELECT DISTINCT oi.OrderID, a.ProductID, a.Price, pr.ChancePct
INTO #AddOns
FROM dbo.OrderItems AS oi
JOIN dbo.Products   AS m  ON m.ProductID = oi.ProductID
JOIN #Pairs         AS pr ON pr.MainProduct = m.ProductName
JOIN dbo.Products   AS a  ON a.ProductName = pr.AddOn
WHERE NOT EXISTS (SELECT 1 FROM dbo.OrderItems AS x
                  WHERE x.OrderID = oi.OrderID AND x.ProductID = a.ProductID);

DROP TABLE IF EXISTS #AddOnsRand;
SELECT OrderID, ProductID, Price, ChancePct, ABS(CHECKSUM(NEWID()) % 100) AS r
INTO #AddOnsRand
FROM #AddOns;

INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice)
SELECT OrderID, ProductID, 1, Price
FROM #AddOnsRand
WHERE r < ChancePct;

/* ---- 8. Payments: one per completed order ----------------------------------- */
DROP TABLE IF EXISTS #P;
SELECT OrderID,
       ABS(CHECKSUM(NEWID()) % 4)   AS PayDelayDays,       -- paid 0-3 days after ordering
       ABS(CHECKSUM(NEWID()) % 100) AS rMethod
INTO #P
FROM dbo.Orders
WHERE Status = N'Completed';

INSERT INTO dbo.Payments (OrderID, Amount, PaymentDate, Method)
SELECT o.OrderID,
       t.OrderTotal,
       CASE WHEN DATEADD(DAY, p.PayDelayDays, o.OrderDate) > @EndDate THEN @EndDate
            ELSE DATEADD(DAY, p.PayDelayDays, o.OrderDate) END,
       CASE WHEN p.rMethod < 50 THEN N'Credit Card'
            WHEN p.rMethod < 80 THEN N'PayPal'
            ELSE N'Bank Transfer' END
FROM dbo.Orders AS o
JOIN #P AS p ON p.OrderID = o.OrderID
JOIN (SELECT OrderID, SUM(Quantity * UnitPrice) AS OrderTotal
      FROM dbo.OrderItems
      GROUP BY OrderID) AS t ON t.OrderID = o.OrderID
ORDER BY o.OrderID;

/* ---- 9. Summary ------------------------------------------------------------- */
SELECT 'Customers'  AS TableName, COUNT(*) AS [Rows] FROM dbo.Customers  UNION ALL
SELECT 'Products',               COUNT(*)          FROM dbo.Products   UNION ALL
SELECT 'Orders',                 COUNT(*)          FROM dbo.Orders     UNION ALL
SELECT 'OrderItems',             COUNT(*)          FROM dbo.OrderItems UNION ALL
SELECT 'Payments',               COUNT(*)          FROM dbo.Payments   UNION ALL
SELECT 'DimDate',                COUNT(*)          FROM dbo.DimDate;
GO
