-- -------------------------------------------------------------------------------------
/* # Customer Segmentation and Behavioral Analysis */
-- -------------------------------------------------------------------------------------
CREATE TABLE TRANSACTIONS (
	UPC BIGINT,
	DOLLAR_SALES NUMERIC,
	UNITS INTEGER,
	TIME_OF_TRANSACTION INTEGER,
	GEOGRAPHY INTEGER,
	WEEK INTEGER,
	HOUSEHOLD INTEGER,
	STORE INTEGER,
	BASKET INTEGER,
	DAY INTEGER,
	COUPON INTEGER
);

CREATE TABLE PRODUCT_LOOKUP (
	UPC BIGINT,
	PRODUCT_DESCRIPTION TEXT,
	COMMODITY TEXT,
	BRAND TEXT,
	PRODUCT_SIZE TEXT
);

CREATE TABLE CASUAL_LOOKUP (
	UPC BIGINT,
	STORE INTEGER,
	WEEK INTEGER,
	FEATURE_DESC TEXT,
	DISPLAY_DESC TEXT,
	GEOGRAPHY INTEGER
);

-- -------------------------------------------------------------------------------------
-- --------------------------------- /* DATA CLEANING */ ---------------------------------
-- -------------------------------------------------------------------------------------
--  ## //NULL CHECKS//

SELECT
	COUNT(*) AS TOTAL_ROWS,
	COUNT(*) FILTER (
		WHERE
			UPC IS NULL
	) AS UPC_NULLS,
	COUNT(*) FILTER (
		WHERE
			HOUSEHOLD IS NULL
	) AS HOUSEHOLD_NULLS,
	COUNT(*) FILTER (
		WHERE
			DOLLAR_SALES IS NULL
	) AS DOLLAR_NULLS,
	COUNT(*) FILTER (
		WHERE
			UNITS IS NULL
	) AS UNITS_NULLS
FROM
	TRANSACTIONS;

SELECT
	COUNT(*) AS TOTAL_ROWS,
	COUNT(*) FILTER (
		WHERE
			UPC IS NULL
	) AS UPC_NULLS,
	COUNT(*) FILTER (
		WHERE
			PRODUCT_DESCRIPTION IS NULL
	) AS PRODUCT_DESCRIPTION_NULLS,
	COUNT(*) FILTER (
		WHERE
			COMMODITY IS NULL
	) AS COMMODITY_NULLS,
	COUNT(*) FILTER (
		WHERE
			BRAND IS NULL
	) AS BRAND_NULLS,
	COUNT(*) FILTER (
		WHERE
			PRODUCT_SIZE IS NULL
	) AS PRODUCT_SIZE_NULLS
FROM
	PRODUCT_LOOKUP;

SELECT
	COUNT(*) AS TOTAL_ROWS,
	COUNT(*) FILTER (
		WHERE
			UPC IS NULL
	) AS UPC_NULLS,
	COUNT(*) FILTER (
		WHERE
			STORE IS NULL
	) AS STORE_NULLS,
	COUNT(*) FILTER (
		WHERE
			WEEK IS NULL
	) AS WEEK_NULLS,
	COUNT(*) FILTER (
		WHERE
			FEATURE_DESC IS NULL
	) AS FEATURE_DESC_NULLS,
	COUNT(*) FILTER (
		WHERE
			DISPLAY_DESC IS NULL
	) AS DISPLAY_DESC_NULLS,
	COUNT(*) FILTER (
		WHERE
			GEOGRAPHY IS NULL
	) AS GEOGRAPHY_NULLS
FROM
	CASUAL_LOOKUP;

-- ## //CHECKS//
-- '-ve' or Zero Sales
SELECT
	*
FROM
	TRANSACTIONS
WHERE
	DOLLAR_SALES <= 0
LIMIT
	10;

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
DELETE FROM TRANSACTIONS
WHERE
	DOLLAR_SALES <= 0;

SELECT
	COUNT(*)
FROM
	TRANSACTIONS
WHERE
	DOLLAR_SALES <= 0;

-- Negative or Zero Units purchased
SELECT
	*
FROM
	TRANSACTIONS
WHERE
	UNITS <= 0
LIMIT
	10;
-- none

-- -------------------------------------------------------------------------------------
--  ## //VALUE CHECKS//
-- day: 1–728
SELECT DISTINCT
	DAY
FROM
	TRANSACTIONS
ORDER BY
	DAY DESC;

-- week: 1–104
SELECT DISTINCT
	WEEK
FROM
	TRANSACTIONS
ORDER BY
	WEEK DESC;

-- Coupon should be 0 or 1.
SELECT DISTINCT
	COUPON
FROM
	TRANSACTIONS;

-- Duplicate Rows
SELECT
	HOUSEHOLD,
	BASKET,
	UPC,
	COUNT(*) AS OCCURRENCES
FROM
	TRANSACTIONS
GROUP BY
	HOUSEHOLD,
	BASKET,
	UPC
HAVING
	COUNT(*) > 1
LIMIT
	10;
--none


-- product data match 
SELECT DISTINCT
	UPC
FROM
	TRANSACTIONS T
WHERE
	NOT EXISTS (
		SELECT
			1
		FROM
			PRODUCT_LOOKUP P
		WHERE
			T.UPC = P.UPC
	);

-- --------------------------------------QUICK STATS------------------------------------
SELECT
	MIN(DOLLAR_SALES) AS MIN_PRICE,
	MAX(DOLLAR_SALES) AS MAX_PRICE,
	AVG(DOLLAR_SALES) AS AVG_PRICE,
	MAX(HOUSEHOLD) AS STARTING_CUSTOMER_ID,
	MIN(HOUSEHOLD) AS ENDING_CUSTOMER_ID,
	MAX(STORE) AS STARTING_STORE_ID,
	MIN(STORE) AS ENDING_STORE_ID,
	MAX(BASKET)AS MAX_TRIPS_TO_STORE,
	MIN(BASKET) AS MIN_TRIPS_TO_STORE,
	MIN(UNITS) AS MIN_UNITS_ORDERED,
	MAX(UNITS) AS MAX_UNITS_ORDERED,
	AVG(UNITS) AS AVG_UNITS_ORDERED
FROM
	TRANSACTIONS;
-- 0.01	153.14	1.7599749657677884	510027	1	387	1	3316349	1	1	156	1.1966966301317478

/*
# Part 1: Household-Level Segmentation

## TO IDENTIFY : 
- High spend / high frequency,
- Low spend / occasional
- Coupon-driven bargain shoppers

## Goal: Build profiles of customer frequency and spend
*/
-- ## 1. unique households 
SELECT
	COUNT(DISTINCT (HOUSEHOLD))
FROM
	TRANSACTIONS;

-- 509935 households
--## 2. total spend, units purchased, and transactions per household
SELECT
	HOUSEHOLD,
	SUM(DOLLAR_SALES) AS TOTAL_SPEND,
	COUNT(DISTINCT BASKET) AS TOTAL_TRANSACTIONS,
	SUM(UNITS) AS TOTAL_UNITS_PURCHASED
FROM
	TRANSACTIONS
GROUP BY
	HOUSEHOLD
ORDER BY
	TOTAL_SPEND DESC,
	TOTAL_TRANSACTIONS DESC,
	TOTAL_UNITS_PURCHASED DESC
;

--## 3. Frequently of households shopping
-- Distribution of transactions per household
WITH
	HOUSEHOLD_TRANSACTION_COUNT AS (
		SELECT
			HOUSEHOLD,
			COUNT(DISTINCT BASKET) AS TRANSACTION_PER_HOUSE
		FROM
			TRANSACTIONS
		GROUP BY
			HOUSEHOLD
	)
SELECT
	TRANSACTION_PER_HOUSE,
	COUNT(HOUSEHOLD) AS NUM_HOUSEHOLDS,
	ROUND(
		(COUNT(HOUSEHOLD) * 100.0) / SUM(COUNT(HOUSEHOLD)) OVER (),
		5
	) AS PERCENTAGE_OF_HOUSEHOLDS
FROM
	HOUSEHOLD_TRANSACTION_COUNT
GROUP BY
	TRANSACTION_PER_HOUSE 
ORDER BY
	TRANSACTION_PER_HOUSE ASC, PERCENTAGE_OF_HOUSEHOLDS DESC;


-- Average days between purchases

WITH
	TOTAL_TRANSACTION_DAYS AS (
		SELECT
			HOUSEHOLD,
			DAY
		FROM
			TRANSACTIONS
		GROUP BY
			HOUSEHOLD,
			DAY
	),
	TRANSACTION_DAYS_DIFFERENCE AS (
		SELECT
			HOUSEHOLD,
			DAY - LAG(DAY) OVER (
				PARTITION BY
					HOUSEHOLD
				ORDER BY
					DAY
			) AS DAYS_BETWEEN_PURCHASES
		FROM
			TOTAL_TRANSACTION_DAYS
	)
SELECT
	HOUSEHOLD,
	ROUND(AVG(DAYS_BETWEEN_PURCHASES), 2) AS AVG_DAYS_BETWEEN_PURCHASES
FROM
	TRANSACTION_DAYS_DIFFERENCE
WHERE
	DAYS_BETWEEN_PURCHASES IS NOT NULL
GROUP BY
	HOUSEHOLD
ORDER BY
	HOUSEHOLD;


	
-- Distribution of Average Days Between Purchases

WITH TOTAL_TRANSACTION_DAYS AS (
    SELECT
        household,
        day
    FROM
        transactions
    GROUP BY
        household,
        day
),
TRANSACTION_DAYS_DIFFERENCE AS (
    SELECT
        household,
        day - LAG(day) OVER (PARTITION BY household ORDER BY day) AS days_between_purchases
    FROM
        TOTAL_TRANSACTION_DAYS
),
HouseholdAverageIntervals AS (
    SELECT
        household,
        AVG(days_between_purchases) AS avg_interval
    FROM
        TRANSACTION_DAYS_DIFFERENCE
    WHERE
        days_between_purchases IS NOT NULL
    GROUP BY
        household
)
SELECT
    AVG(avg_interval) AS overall_average_shopping_interval,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_interval) AS median_shopping_interval
FROM
    HouseholdAverageIntervals;



-- # 4. Percent of households used coupons
--  Overall coupon penetration

with totaluniquehouseholds as (
    select
        count(distinct household) as total_households
    from
        transactions),
householdswithcoupons as (
    select
        count(distinct household) as households_used_coupons
    from
        transactions
    where
        coupon = 1)
select
    round((hwc.households_used_coupons * 100.0) / tuh.total_households,3) as percent_households_used_coupons
from
    householdswithcoupons hwc,
    totaluniquehouseholds tuh;
-- 7.789
	
-- Coupon usage rate per household

SELECT 	
	HOUSEHOLD, 	
	COUNT(DISTINCT BASKET) AS TOTALTRANSACTIONS,
	COUNT(DISTINCT CASE WHEN coupon = 1 THEN basket END) AS coupon_transactions,
	ROUND
		(COUNT(
			DISTINCT CASE WHEN COUPON = 1 THEN BASKET END) * 100 / 
				COUNT(
					DISTINCT BASKET),2) AS COUPONED_USAGE_PER_TRANSACTION
FROM
	TRANSACTIONS
GROUP BY
	HOUSEHOLD
HAVING
	COUNT(DISTINCT BASKET) > 0
ORDER BY
	COUPONED_USAGE_PER_TRANSACTION DESC,TOTALTRANSACTIONS desc;


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
