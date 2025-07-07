CREATE TABLE transactions (
    upc BIGINT,
    dollar_sales NUMERIC,
    units INTEGER,
    time_of_transaction INTEGER,
    geography INTEGER,
    week INTEGER,
    household INTEGER,
    store INTEGER,
    basket INTEGER,
    day INTEGER,
    coupon INTEGER
);

CREATE TABLE product_lookup (
    upc BIGINT,
    product_description TEXT,
    commodity TEXT,
    brand TEXT,
    product_size TEXT
);


CREATE TABLE casual_lookup (
    upc BIGINT,
    store INTEGER,
    week INTEGER,
    feature_desc TEXT,
    display_desc TEXT,
    geography INTEGER
);


-- -------------------------------------------------------------------------------------
-- --------------------------------- /*DATA CLEANING*/ ---------------------------------
-- -------------------------------------------------------------------------------------

SELECT
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE upc IS NULL) AS upc_nulls,
  COUNT(*) FILTER (WHERE household IS NULL) AS household_nulls,
  COUNT(*) FILTER (WHERE dollar_sales IS NULL) AS dollar_nulls,
  COUNT(*) FILTER (WHERE units IS NULL) AS units_nulls
FROM transactions;


SELECT
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE upc IS NULL) AS upc_nulls,
  COUNT(*) FILTER (WHERE product_description IS NULL) AS product_description_nulls,
  COUNT(*) FILTER (WHERE commodity IS NULL) AS commodity_nulls,
  COUNT(*) FILTER (WHERE brand IS NULL) AS brand_nulls,
  COUNT(*) FILTER (WHERE product_size IS NULL) AS product_size_nulls  
FROM product_lookup;


SELECT
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE upc IS NULL) AS upc_nulls,
  COUNT(*) FILTER (WHERE store IS NULL) AS store_nulls,
  COUNT(*) FILTER (WHERE week IS NULL) AS week_nulls,
  COUNT(*) FILTER (WHERE feature_desc IS NULL) AS feature_desc_nulls,
  COUNT(*) FILTER (WHERE display_desc IS NULL) AS display_desc_nulls,  
  COUNT(*) FILTER (WHERE geography IS NULL) AS geography_nulls
FROM casual_lookup;

-- '-ve' or Zero Sales
SELECT *
FROM transactions
WHERE dollar_sales <= 0
LIMIT 10;

/*
3340060109,
3340060108,
3340060709,
5100015055,
3340060109,
7680851829,
3340060110,
3340060709,
3340060108,
5100015055
*/

--dropping rows with -ve and 0 slaes 

DELETE FROM transactions
WHERE dollar_sales <= 0;

SELECT COUNT(*) FROM transactions WHERE dollar_sales <= 0;


-- Negative or Zero Units purchased
SELECT *
FROM transactions
WHERE units <= 0
LIMIT 10;
-- none

-- -------------------------------------------------------------------------------------
--  CHECKS

-- day: 1–728
SELECT DISTINCT day
FROM transactions
ORDER BY day desc;


-- week: 1–104
SELECT DISTINCT week
FROM transactions
ORDER BY week desc;

-- Coupon should be 0 or 1.
SELECT DISTINCT coupon
FROM transactions;


-- Duplicate Rows
SELECT household, basket, upc, COUNT(*) AS occurrences
FROM transactions
GROUP BY household, basket, upc
HAVING COUNT(*) > 1
LIMIT 10;
--none

-- product data match 
SELECT DISTINCT upc 
FROM transactions t
WHERE NOT EXISTS (
  SELECT 1 FROM product_lookup p WHERE t.upc = p.upc
)
;

-- --------------------------------------QUICK STATS------------------------------------
SELECT
  MIN(dollar_sales),
  MAX(dollar_sales),
  AVG(dollar_sales),
  MIN(units),
  MAX(units),
  AVG(units)
FROM transactions;

-- -------------------------------------------------------------------------------------
/*# Customer Segmentation and Behavioral Analysis*/
-- -------------------------------------------------------------------------------------

/*
# Part 1: Household-Level Segmentation

TO IDENTIFY : 
	- High spend / high frequency,
	- Low spend / occasional
	- Coupon-driven bargain shoppers

## Goal: Build profiles of customer frequency and spend
*/
-- 1. unique households 
SELECT count(distinct(household)) from transactions;
-- 509935 households


-- 2. total spend, units purchased, and transactions per household?
select household, sum(dollar_sales) as revenue, count(upc) as frequency, sum(units) as units_purchased
from transactions 
group by household
order by revenue desc, frequency desc, units_purchased desc
;




--3. How frequently do households shop?
		-- Distribution of transactions per household
select 


	
		-- Average days between purchases







/*

4. What percent of households used coupons?
	- Overall coupon penetration
	- Coupon usage rate per household

*/

-- -------------------------------------------------------------------------------------
/*
# Part 2: Loyalty & Switching

## Goal: Assess brand/category loyalty and switching

5. What percent of category shoppers are loyal to a single brand?
6. What percent switch brands within a category?
	- Identify households purchasing multiple brands of Pasta
7. Among households who used a coupon to try a brand for the first time, how many re-purchased that brand without a coupon?
	- Shows coupon-driven trial vs. retention
*/
-- -------------------------------------------------------------------------------------


/*
#Part 3: Cross-Category Behavior

## Goal: Explore opportunities for cross-sell

8. How many households purchased both Pasta and Pasta Sauce?
	- Penetration of cross-category shoppers
9. What are the most common product combinations across categories
   	 E.g., Barilla Pasta + Ragu Sauce
10. Are there households who buy only one category?
	- Potential to target with cross-promotions
*/

-- -------------------------------------------------------------------------------------


/*

#Part 4: Coupon Influence

## Goal: Measure impact of coupons on behavior

11. What percent of transactions involved coupons?
	- By category
	- Over time
12. Did customers first purchase an item or category using a coupon?
	- If so, did they become repeat buyers?
13. Is coupon usage higher among low-frequency or high-frequency households?
*/
-- -------------------------------------------------------------------------------------

/*
#Part 5: RFM segmentation

14. Recency-Frequency-Monetary (RFM) Segmentation:
   	- When did households last purchase?
    	- How frequently do they buy?
    	- How much do they spend?

15. Category Penetration:
    	- For each category, what percent of total households participated?
    	- E.g., “68% of households purchased Pasta Sauce”

16.  Brand Switching Triggers:
	- Are brand switchers more likely to have used coupons or promotions?
*/

