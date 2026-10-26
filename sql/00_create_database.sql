/* =============================================================================
   00_create_database.sql
   Creates the SalesDB database (safe to re-run).
   ============================================================================= */
IF DB_ID('SalesDB') IS NULL
    CREATE DATABASE SalesDB;
GO

USE SalesDB;
GO
