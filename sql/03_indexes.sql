/* =============================================================================
   03_indexes.sql
   Indexes that support the joins and date filters used in the analysis.
   (Primary keys and UNIQUE constraints already create indexes on
    OrderItems(OrderID, ProductID) and Payments(OrderID).)

   How to measure the effect (see docs/performance_tuning.md):
     SET STATISTICS IO, TIME ON;
     -- run a query from 05/06 before and after this script,
     -- compare "logical reads" and "elapsed time" in the Messages tab,
     -- and look at the actual execution plan (Ctrl+M in SSMS).
   ============================================================================= */
USE SalesDB;
GO

DROP INDEX IF EXISTS IX_Orders_CustomerID     ON dbo.Orders;
DROP INDEX IF EXISTS IX_Orders_Status_Date    ON dbo.Orders;
DROP INDEX IF EXISTS IX_OrderItems_ProductID  ON dbo.OrderItems;
DROP INDEX IF EXISTS IX_Payments_PaymentDate  ON dbo.Payments;
GO

-- Customer-level analysis (CLV, RFM, cohorts) joins Orders on CustomerID
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID
    ON dbo.Orders (CustomerID) INCLUDE (OrderDate, Status);

-- Most queries filter Status = 'Completed' and group by date
CREATE NONCLUSTERED INDEX IX_Orders_Status_Date
    ON dbo.Orders (Status, OrderDate) INCLUDE (CustomerID);

-- Product / category revenue and basket analysis
CREATE NONCLUSTERED INDEX IX_OrderItems_ProductID
    ON dbo.OrderItems (ProductID) INCLUDE (OrderID, Quantity, UnitPrice);

-- Monthly revenue groups payments by date
CREATE NONCLUSTERED INDEX IX_Payments_PaymentDate
    ON dbo.Payments (PaymentDate) INCLUDE (Amount, OrderID, Method);
GO
