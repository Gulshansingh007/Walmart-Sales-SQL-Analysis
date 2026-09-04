-- ============================================================
-- CREATE DATABASE
-- ============================================================

CREATE DATABASE SalesDataWalmart;

USE SalesDataWalmart;


-- ============================================================
-- STAGING TABLE
-- Import CSV data here first
-- ============================================================

CREATE TABLE sales_raw
(
    invoice_id VARCHAR(30),
    branch VARCHAR(5),
    city VARCHAR(30),
    customer_type VARCHAR(30),
    gender VARCHAR(10),
    product_line VARCHAR(100),
    unit_price VARCHAR(30),
    quantity VARCHAR(30),
    VAT VARCHAR(30),
    total VARCHAR(30),
    [date] VARCHAR(30),
    [time] VARCHAR(30),
    payment_method VARCHAR(30),
    cogs VARCHAR(30),
    gross_margin_pct VARCHAR(30),
    gross_income VARCHAR(30),
    rating VARCHAR(30)
);


-- ============================================================
-- IMPORT CSV
-- ============================================================

BULK INSERT sales_raw
FROM 'C:\Users\HP\Downloads\WalmartSalesData.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);


-- ============================================================
-- CHECK RAW DATA
-- ============================================================

SELECT TOP 10 *
FROM sales_raw;

SELECT COUNT(*) AS total_rows
FROM sales_raw;


-- ============================================================
-- CREATE FINAL SALES TABLE
-- ============================================================

CREATE TABLE sales
(
    invoice_id VARCHAR(30) NOT NULL PRIMARY KEY,
    branch VARCHAR(5) NOT NULL,
    city VARCHAR(30) NOT NULL,
    customer_type VARCHAR(30) NOT NULL,
    gender VARCHAR(10) NOT NULL,
    product_line VARCHAR(100) NOT NULL,

    unit_price DECIMAL(10,2) NOT NULL,
    quantity INT NOT NULL,

    VAT DECIMAL(6,4) NOT NULL,
    total DECIMAL(12,4) NOT NULL,

    [date] DATE NOT NULL,
    [time] TIME NOT NULL,

    payment_method VARCHAR(15) NOT NULL,

    cogs DECIMAL(10,2) NOT NULL,
    gross_margin_pct DECIMAL(11,9),
    gross_income DECIMAL(12,4) NOT NULL,
    rating DECIMAL(2,1)
);


-- ============================================================
-- ============================================================
-- MOVE DATA FROM RAW TABLE TO FINAL TABLE
-- ============================================================

INSERT INTO sales
(
    invoice_id,
    branch,
    city,
    customer_type,
    gender,
    product_line,
    unit_price,
    quantity,
    VAT,
    total,
    [date],
    [time],
    payment_method,
    cogs,
    gross_margin_pct,
    gross_income,
    rating
)
SELECT
    invoice_id,
    branch,
    city,
    customer_type,
    gender,
    product_line,

    TRY_CONVERT(DECIMAL(10,2), unit_price),
    TRY_CONVERT(INT, quantity),

    TRY_CONVERT(DECIMAL(6,4), VAT),
    TRY_CONVERT(DECIMAL(12,4), total),

    TRY_CONVERT(DATE, [date]),
    TRY_CONVERT(TIME, [time]),

    payment_method,

    TRY_CONVERT(DECIMAL(10,2), cogs),
    TRY_CONVERT(DECIMAL(11,9), gross_margin_pct),
    TRY_CONVERT(DECIMAL(12,4), gross_income),
    TRY_CONVERT(
        DECIMAL(2,1),
        REPLACE(LTRIM(RTRIM(rating)), CHAR(13), '')
        )

FROM sales_raw;

-- ============================================================
-- CHECK FINAL TABLE
-- ============================================================

SELECT TOP 10 *
FROM sales;

SELECT COUNT(*) AS total_rows
FROM sales;


-- ============================================================
-- FEATURE ENGINEERING
-- ============================================================


-- ------------------------------------------------------------
-- TIME OF DAY
-- ------------------------------------------------------------

ALTER TABLE sales
ADD time_of_day VARCHAR(20);


UPDATE sales
SET time_of_day =
    CASE
        WHEN [time] BETWEEN '00:00:00' AND '12:00:00'
            THEN 'Morning'

        WHEN [time] BETWEEN '12:01:00' AND '16:00:00'
            THEN 'Afternoon'

        ELSE 'Evening'
    END;


-- Check

SELECT
    [time],
    time_of_day
FROM sales;


-- ------------------------------------------------------------
-- DAY NAME
-- ------------------------------------------------------------

ALTER TABLE sales
ADD day_name VARCHAR(10);


UPDATE sales
SET day_name = DATENAME(WEEKDAY, [date]);


-- Check

SELECT
    [date],
    day_name
FROM sales;


-- ------------------------------------------------------------
-- MONTH NAME
-- ------------------------------------------------------------



ALTER TABLE sales
ADD month_name VARCHAR(10);


UPDATE sales
SET month_name = DATENAME(MONTH, [date]);


-- Check

SELECT
    [date],
    month_name
FROM sales;


-- ============================================================
-- GENERIC
-- ============================================================


-- 1. How many unique cities does the data have?

SELECT DISTINCT
    city
FROM sales;


-- 2. In which city is each branch?

SELECT DISTINCT
    branch,
    city
FROM sales;


-- 3. How many unique product lines?

SELECT
    COUNT(DISTINCT product_line) AS unique_product_lines
FROM sales;


-- 4. What is the most common payment method?

SELECT
    payment_method,
    COUNT(*) AS cnt
FROM sales
GROUP BY payment_method
ORDER BY cnt DESC;


-- 5. What is the most selling product line?

SELECT
    product_line,
    COUNT(*) AS cnt
FROM sales
GROUP BY product_line
ORDER BY cnt DESC;


-- 6. What is the total revenue by month?

SELECT
    month_name AS month,
    SUM(total) AS total_revenue
FROM sales
GROUP BY month_name
ORDER BY total_revenue DESC;


-- 7. What month had the largest COGS?

SELECT
    month_name AS month,
    SUM(cogs) AS total_cogs
FROM sales
GROUP BY month_name
ORDER BY total_cogs DESC;


-- 8. What product line had the largest revenue?

SELECT
    product_line,
    SUM(total) AS total_revenue
FROM sales
GROUP BY product_line
ORDER BY total_revenue DESC;


-- 9. What city had the largest revenue?

SELECT
    branch,
    city,
    SUM(total) AS total_revenue
FROM sales
GROUP BY branch, city
ORDER BY total_revenue DESC;


-- 10. What product line had the largest VAT?

SELECT
    product_line,
    AVG(VAT) AS avg_tax
FROM sales
GROUP BY product_line
ORDER BY avg_tax DESC;


-- 11. Product line performance: GOOD / BAD

SELECT
    product_line,
    SUM(quantity) AS total_quantity,

    CASE
        WHEN SUM(quantity) >
        (
            SELECT AVG(total_quantity)
            FROM
            (
                SELECT
                    SUM(quantity) AS total_quantity
                FROM sales
                GROUP BY product_line
            ) AS product_sales
        )
        THEN 'Good'
        ELSE 'Bad'
    END AS performance

FROM sales
GROUP BY product_line;


-- 12. Most selling product line by gender

SELECT
    gender,
    product_line,
    COUNT(*) AS total_cnt
FROM sales
GROUP BY gender, product_line
ORDER BY gender, total_cnt DESC;


-- 13. Average rating of each product line

SELECT
    product_line,
    AVG(rating) AS avg_rating
FROM sales
GROUP BY product_line
ORDER BY avg_rating DESC;


-- ============================================================
-- SALES
-- ============================================================


-- 14. Number of sales in each time of day

SELECT
    time_of_day,
    COUNT(*) AS total_sales
FROM sales
GROUP BY time_of_day
ORDER BY total_sales DESC;


-- 15. Number of sales by time of day per weekday

SELECT
    day_name,
    time_of_day,
    COUNT(*) AS total_sales
FROM sales
GROUP BY day_name, time_of_day
ORDER BY day_name, total_sales DESC;


-- 16. Which customer type brings the most revenue?

SELECT
    customer_type,
    SUM(total) AS total_revenue
FROM sales
GROUP BY customer_type
ORDER BY total_revenue DESC;


-- 17. Which city has the largest VAT?

SELECT
    city,
    AVG(VAT) AS avg_VAT
FROM sales
GROUP BY city
ORDER BY avg_VAT DESC;


-- 18. Which customer type pays the most VAT?

SELECT
    customer_type,
    AVG(VAT) AS avg_VAT
FROM sales
GROUP BY customer_type
ORDER BY avg_VAT DESC;


-- ============================================================
-- CUSTOMERS
-- ============================================================


-- 19. Unique customer types

SELECT DISTINCT
    customer_type
FROM sales;


-- 20. Unique payment methods

SELECT DISTINCT
    payment_method
FROM sales;


-- 21. Which customer type buys the most?

SELECT
    customer_type,
    COUNT(*) AS customer_count
FROM sales
GROUP BY customer_type
ORDER BY customer_count DESC;


-- 22. Which gender has the most customers?

SELECT
    gender,
    COUNT(*) AS gender_count
FROM sales
GROUP BY gender
ORDER BY gender_count DESC;


-- 23. Which time of day has the highest average rating?

SELECT
    time_of_day,
    AVG(rating) AS avg_rating
FROM sales
GROUP BY time_of_day
ORDER BY avg_rating DESC;


-- 24. Which time of day has the highest average rating
--     in Branch C?

SELECT
    time_of_day,
    AVG(rating) AS avg_rating
FROM sales
WHERE branch = 'C'
GROUP BY time_of_day
ORDER BY avg_rating DESC;


-- 25. Which day of the week has the best average rating?

SELECT
    day_name,
    AVG(rating) AS avg_rating
FROM sales
GROUP BY day_name
ORDER BY avg_rating DESC;