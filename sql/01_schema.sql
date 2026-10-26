/* =============================================================================
   01_schema.sql
   Tables with keys, NOT NULL rules and CHECK constraints so bad data
   cannot get in. Safe to re-run: drops the tables first (child tables first).
   ============================================================================= */
USE SalesDB;
GO

DROP TABLE IF EXISTS dbo.Payments;
DROP TABLE IF EXISTS dbo.OrderItems;
DROP TABLE IF EXISTS dbo.Orders;
DROP TABLE IF EXISTS dbo.Products;
DROP TABLE IF EXISTS dbo.Customers;
DROP TABLE IF EXISTS dbo.DimDate;
GO

CREATE TABLE dbo.Customers (
    CustomerID  INT IDENTITY(1,1) CONSTRAINT PK_Customers PRIMARY KEY,
    FullName    NVARCHAR(100) NOT NULL,
    Email       NVARCHAR(100) NOT NULL CONSTRAINT UQ_Customers_Email UNIQUE,
    Country     NVARCHAR(50)  NOT NULL,
    CreatedAt   DATE          NOT NULL
);

CREATE TABLE dbo.Products (
    ProductID   INT IDENTITY(1,1) CONSTRAINT PK_Products PRIMARY KEY,
    ProductName NVARCHAR(100) NOT NULL,
    Category    NVARCHAR(50)  NOT NULL,
    Price       DECIMAL(10,2) NOT NULL CONSTRAINT CK_Products_Price CHECK (Price > 0)
);

CREATE TABLE dbo.Orders (
    OrderID     INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerID  INT          NOT NULL CONSTRAINT FK_Orders_Customers REFERENCES dbo.Customers(CustomerID),
    OrderDate   DATE         NOT NULL,
    Status      NVARCHAR(30) NOT NULL
        CONSTRAINT CK_Orders_Status CHECK (Status IN ('Completed', 'Cancelled'))
);

CREATE TABLE dbo.OrderItems (
    OrderItemID INT IDENTITY(1,1) CONSTRAINT PK_OrderItems PRIMARY KEY,
    OrderID     INT           NOT NULL CONSTRAINT FK_OrderItems_Orders   REFERENCES dbo.Orders(OrderID),
    ProductID   INT           NOT NULL CONSTRAINT FK_OrderItems_Products REFERENCES dbo.Products(ProductID),
    Quantity    INT           NOT NULL CONSTRAINT CK_OrderItems_Quantity  CHECK (Quantity > 0),
    UnitPrice   DECIMAL(10,2) NOT NULL CONSTRAINT CK_OrderItems_UnitPrice CHECK (UnitPrice > 0),
    CONSTRAINT UQ_OrderItems_Order_Product UNIQUE (OrderID, ProductID)   -- one line per product per order
);

CREATE TABLE dbo.Payments (
    PaymentID   INT IDENTITY(1,1) CONSTRAINT PK_Payments PRIMARY KEY,
    OrderID     INT           NOT NULL CONSTRAINT FK_Payments_Orders REFERENCES dbo.Orders(OrderID)
                              CONSTRAINT UQ_Payments_Order UNIQUE,            -- one payment per order
    Amount      DECIMAL(12,2) NOT NULL CONSTRAINT CK_Payments_Amount CHECK (Amount > 0),
    PaymentDate DATE          NOT NULL,
    Method      NVARCHAR(30)  NOT NULL
        CONSTRAINT CK_Payments_Method CHECK (Method IN ('Credit Card', 'PayPal', 'Bank Transfer'))
);

-- Calendar table for Power BI time intelligence (filled in 02_sample_data.sql)
CREATE TABLE dbo.DimDate (
    [Date]      DATE        NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
    [Year]      INT         NOT NULL,
    [Quarter]   INT         NOT NULL,
    [Month]     INT         NOT NULL,
    MonthName   NVARCHAR(20) NOT NULL,
    MonthStart  DATE        NOT NULL,
    YearMonth   CHAR(7)     NOT NULL,     -- '2025-03'
    [DayOfWeek] NVARCHAR(20) NOT NULL,
    IsWeekend   BIT         NOT NULL
);
GO
