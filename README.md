# Sales Performance & Customer Insights - SQL Server Project

## 1. Project Overview
This project demonstrates a complete Sales Analytics solution using SQL Server.  
It simulates an online retail business, with Customers, Products, Orders, OrderItems, and Payments tables.  
The goal is to generate insights for revenue, customer behavior, and product performance.

---

## 2. Business Questions / KPIs
1. Monthly revenue trend  
2. Top 10 customers by Lifetime Value (CLV)  
3. Repeat customers & retention  
4. Average Order Value (AOV)  
5. Top products by revenue  
6. Revenue by category & country  
7. Cohort analysis of new customers  
8. Customer ranking & segmentation  

---

## 3. Database Schema
- **Customers**: CustomerID, FullName, Email, Country, CreatedAt  
- **Products**: ProductID, ProductName, Category, Price  
- **Orders**: OrderID, CustomerID, OrderDate, Status  
- **OrderItems**: OrderItemID, OrderID, ProductID, Quantity, UnitPrice  
- **Payments**: PaymentID, OrderID, Amount, PaymentDate, Method  


---

## 4. Dataset
- Customers: 1,000  
- Orders: 5,000  
- OrderItems: 15,000  
- Payments: 5,000  
- Products: 50  
Generated using T-SQL scripts in `sample_data.sql`.  

---

## 5. Analysis Queries
Available in `analysis_queries.sql`:

- Monthly revenue trends  
- Top customers by spending  
- Repeat customer counts  
- Average Order Value  
- Top-selling products & categories  
- Revenue by country  
- Cohort analysis & retention  
- Customer ranking with window functions  

---
## 6. Power BI Dashboard

The Power BI dashboard provides interactive insights into:
- Revenue trends over time
- Top customers and repeat behavior
- Product and category performance
- Customer growth and retention

### Dashboard Preview
![Revenue Overview](powerbi/screenshots/revenue_overview.png)
![Customer Insights](powerbi/screenshots/customer_insights.png)

       SUM(Amount) AS TotalRevenue
FROM Payments
GROUP BY FORMAT(PaymentDate, 'yyyy-MM');

---
## 7. Views
Optional views for repeated analysis, e.g.,:

```sql
CREATE VIEW vw_MonthlyRevenue AS
SELECT FORMAT(PaymentDate, 'yyyy-MM') AS YearMonth,





