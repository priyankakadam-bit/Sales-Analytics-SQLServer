CREATE TABLE Customers (
    CustomerID INT IDENTITY PRIMARY KEY,
    FullName NVARCHAR(100),
    Email NVARCHAR(100),
    Country NVARCHAR(50),
    CreatedAt DATE
);

CREATE TABLE Products (
    ProductID INT IDENTITY PRIMARY KEY,
    ProductName NVARCHAR(100),
    Category NVARCHAR(50),
    Price DECIMAL(10,2)
);

CREATE TABLE Orders (
    OrderID INT IDENTITY PRIMARY KEY,
    CustomerID INT,
    OrderDate DATE,
    Status NVARCHAR(30),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

CREATE TABLE OrderItems (
    OrderItemID INT IDENTITY PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    UnitPrice DECIMAL(10,2),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);

CREATE TABLE Payments (
    PaymentID INT IDENTITY PRIMARY KEY,
    OrderID INT, 
    Amount DECIMAL(10,2),
    PaymentDate DATE,
    Method NVARCHAR(30),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID)
);


