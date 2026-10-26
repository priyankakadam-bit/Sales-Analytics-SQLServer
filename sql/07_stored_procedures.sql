/* =============================================================================
   07_stored_procedures.sql
   Parameterised reports.

   Examples:
     EXEC dbo.usp_SalesSummary @StartDate = '2025-01-01', @EndDate = '2025-12-31';
     EXEC dbo.usp_TopCustomers @TopN = 5, @Country = N'France';
     EXEC dbo.usp_CustomerProfile @CustomerID = 42;
   ============================================================================= */
USE SalesDB;
GO

/* KPIs for any date range, plus category breakdown */
CREATE OR ALTER PROCEDURE dbo.usp_SalesSummary
    @StartDate DATE,
    @EndDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartDate > @EndDate
        THROW 50001, 'StartDate must be on or before EndDate.', 1;

    -- Result 1: headline KPIs
    SELECT @StartDate                                     AS StartDate,
           @EndDate                                       AS EndDate,
           COUNT(*)                                       AS Orders,
           SUM(CASE WHEN Status = 'Completed' THEN 1 ELSE 0 END) AS CompletedOrders,
           ISNULL(SUM(PaidAmount), 0)                     AS Revenue,
           CAST(AVG(PaidAmount) AS DECIMAL(12,2))         AS AvgOrderValue,
           COUNT(DISTINCT CASE WHEN Status = 'Completed' THEN CustomerID END) AS Customers,
           SUM(IsFirstOrder)                              AS NewCustomers,
           CAST(100.0 * SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END)
                / NULLIF(COUNT(*), 0) AS DECIMAL(5,1))    AS CancelRatePct
    FROM dbo.vw_OrderSummary
    WHERE OrderDate BETWEEN @StartDate AND @EndDate;

    -- Result 2: revenue by category
    SELECT pr.Category,
           SUM(oi.Quantity * oi.UnitPrice) AS Revenue,
           SUM(oi.Quantity)                AS UnitsSold
    FROM dbo.OrderItems AS oi
    JOIN dbo.Orders     AS o  ON o.OrderID = oi.OrderID AND o.Status = 'Completed'
    JOIN dbo.Products   AS pr ON pr.ProductID = oi.ProductID
    WHERE o.OrderDate BETWEEN @StartDate AND @EndDate
    GROUP BY pr.Category
    ORDER BY Revenue DESC;
END;
GO

/* Top N customers, optionally for one country */
CREATE OR ALTER PROCEDURE dbo.usp_TopCustomers
    @TopN    INT          = 10,
    @Country NVARCHAR(50) = NULL      -- NULL = all countries
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
           CustomerID, FullName, Country, CompletedOrders, LifetimeValue, LastOrderDate
    FROM dbo.vw_CustomerLifetimeValue
    WHERE (@Country IS NULL OR Country = @Country)
    ORDER BY LifetimeValue DESC
    OPTION (RECOMPILE);               -- a fresh plan for "all" vs "one country"
END;
GO

/* Everything about one customer */
CREATE OR ALTER PROCEDURE dbo.usp_CustomerProfile
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerID = @CustomerID)
        THROW 50002, 'Customer not found.', 1;

    SELECT v.*, r.Segment, r.RFMScore
    FROM dbo.vw_CustomerLifetimeValue AS v
    LEFT JOIN dbo.vw_CustomerRFM      AS r ON r.CustomerID = v.CustomerID
    WHERE v.CustomerID = @CustomerID;

    SELECT OrderID, OrderDate, Status, ItemLines, OrderTotal, PaymentMethod
    FROM dbo.vw_OrderSummary
    WHERE CustomerID = @CustomerID
    ORDER BY OrderDate DESC;
END;
GO
