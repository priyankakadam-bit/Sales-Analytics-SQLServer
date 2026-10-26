# Performance Tuning Notes

## Indexes (`sql/03_indexes.sql`)

| Index | Columns | Helps |
|---|---|---|
| `IX_Orders_CustomerID` | Orders(CustomerID) INCLUDE (OrderDate, Status) | Customer lifetime value, RFM, cohorts |
| `IX_Orders_Status_Date` | Orders(Status, OrderDate) INCLUDE (CustomerID) | Every query that filters `Status = 'Completed'` and groups by date |
| `IX_OrderItems_ProductID` | OrderItems(ProductID) INCLUDE (OrderID, Quantity, UnitPrice) | Product and category revenue, basket analysis |
| `IX_Payments_PaymentDate` | Payments(PaymentDate) INCLUDE (Amount, OrderID, Method) | Monthly revenue, payment-method mix |

Already indexed by constraints: all primary keys, `OrderItems(OrderID, ProductID)` (unique),
`Payments(OrderID)` (unique), `Customers(Email)` (unique).

`INCLUDE` columns make the indexes *covering*: the query finds everything it needs in the index
and does not have to look up the base table (no key lookups).

## Query-level choices
- `DATEFROMPARTS(YEAR(d), MONTH(d), 1)` instead of `FORMAT(d, 'yyyy-MM')` - `FORMAT` calls .NET for
  every row and is much slower on large tables.
- Aggregate in a subquery or CTE first, then join (e.g. order totals before joining to customers).
- Views hold repeated logic once (revenue = completed orders only).
- `OPTION (RECOMPILE)` in `usp_TopCustomers` so the "all countries" and "one country" calls each get a fitting plan.

## How to measure
```sql
SET STATISTICS IO, TIME ON;
-- 1. Drop the indexes (run the DROP INDEX lines from 03_indexes.sql)
-- 2. Run a query, e.g. the RFM summary from 06_advanced_analysis.sql
-- 3. Note "logical reads" and "elapsed time" from the Messages tab
-- 4. Create the indexes again (03_indexes.sql) and repeat
```
Turn on **Include Actual Execution Plan** (Ctrl+M in SSMS) to see table scans turn into index seeks.

## Results
*(Fill in with your own measurements.)*

| Query | Logical reads before | after | Elapsed ms before | after |
|---|---|---|---|---|
| Monthly revenue | | | | |
| Top 10 customers | | | | |
| RFM summary | | | | |

With only a few thousand rows every query is fast either way. For a convincing demo, raise
`@NumCustomers` and `@RepeatAttempts` in `02_sample_data.sql` (e.g. ×20) before measuring.
