# Performance Tuning Notes

## Indexes Added
1. Orders(CustomerID) – speeds up customer join queries
2. Payments(PaymentDate) – speeds up monthly revenue queries
3. OrderItems(OrderID, ProductID) – speeds up product & order aggregation

## Execution Plan
- Without indexes: full table scan
- With indexes: index seek → much faster aggregation
- Query optimization used joins + group by + window functions

## Best Practices
- Use views for repeated KPIs
- Aggregate first, filter later
- Keep Payment linked to Completed Orders
