/* =============================================================================
   08_data_quality_checks.sql
   Every check should return 0 problem rows. Run after loading data.
   ============================================================================= */
USE SalesDB;
GO

WITH order_totals AS (
    SELECT OrderID, SUM(Quantity * UnitPrice) AS Total
    FROM dbo.OrderItems
    GROUP BY OrderID
),
checks AS (
    SELECT 'Orders without any items' AS CheckName,
           (SELECT COUNT(*) FROM dbo.Orders AS o
            WHERE NOT EXISTS (SELECT 1 FROM dbo.OrderItems AS oi WHERE oi.OrderID = o.OrderID)) AS ProblemRows
    UNION ALL
    SELECT 'Completed orders without a payment',
           (SELECT COUNT(*) FROM dbo.Orders AS o
            WHERE o.Status = 'Completed'
              AND NOT EXISTS (SELECT 1 FROM dbo.Payments AS p WHERE p.OrderID = o.OrderID))
    UNION ALL
    SELECT 'Cancelled orders with a payment',
           (SELECT COUNT(*) FROM dbo.Orders AS o
            JOIN dbo.Payments AS p ON p.OrderID = o.OrderID
            WHERE o.Status = 'Cancelled')
    UNION ALL
    SELECT 'Payment amount differs from order total',
           (SELECT COUNT(*) FROM dbo.Payments AS p
            JOIN order_totals AS t ON t.OrderID = p.OrderID
            WHERE p.Amount <> t.Total)
    UNION ALL
    SELECT 'Orders placed before customer sign-up',
           (SELECT COUNT(*) FROM dbo.Orders AS o
            JOIN dbo.Customers AS c ON c.CustomerID = o.CustomerID
            WHERE o.OrderDate < c.CreatedAt)
    UNION ALL
    SELECT 'Payments dated before the order',
           (SELECT COUNT(*) FROM dbo.Payments AS p
            JOIN dbo.Orders AS o ON o.OrderID = p.OrderID
            WHERE p.PaymentDate < o.OrderDate)
    UNION ALL
    SELECT 'Items sold above list price',
           (SELECT COUNT(*) FROM dbo.OrderItems AS oi
            JOIN dbo.Products AS pr ON pr.ProductID = oi.ProductID
            WHERE oi.UnitPrice > pr.Price)
    UNION ALL
    SELECT 'Order dates outside the calendar table',
           (SELECT COUNT(*) FROM dbo.Orders AS o
            WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate AS d WHERE d.[Date] = o.OrderDate))
)
SELECT CheckName,
       ProblemRows,
       CASE WHEN ProblemRows = 0 THEN 'OK' ELSE 'CHECK' END AS Result
FROM checks;
