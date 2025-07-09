-- -------------------------------------------------------------------------------------
/*# Customer Segmentation and Behavioral Analysis*/
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
-- --------------------------------- /*DATA CLEANING*/ ---------------------------------
-- -------------------------------------------------------------------------------------
--  ## //NULL CHECKS//
-- -------------------------------------------------------------------------------------
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

-- -------------------------------------------------------------------------------------
-- ## //CHECKS//
-- -------------------------------------------------------------------------------------
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

-- -------------------------------------------------------------------------------------
--dropping rows with -ve and 0 slaes 

SELECT
	COUNT(*)
FROM
	TRANSACTIONS
WHERE
	DOLLAR_SALES <= 0;

	
DELETE FROM TRANSACTIONS
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
-- -------------------------------------------------------------------------------------
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
-- -------------------------------------------------------------------------------------
-- ---------------------------------------ANALYSIS--------------------------------------
-- -------------------------------------------------------------------------------------
-- # Part 1: Household-Level Segmentation
-- -------------------------------------------------------------------------------------
-- ## TO IDENTIFY : 
-- High spend / high frequency,
-- Low spend / occasional
-- Coupon-driven bargain shoppers
-- -------------------------------------------------------------------------------------
-- 1.1 unique households 

SELECT
	COUNT(DISTINCT (HOUSEHOLD))
FROM
	TRANSACTIONS
;

-- 509935 households


-- -------------------------------------------------------------------------------------
-- 1.2 total spend, units purchased, and transactions per household

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

-- -------------------------------------------------------------------------------------
--1.3 How frequently do households shop? Distribution of transactions per household

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

-- -------------------------------------------------------------------------------------
-- 4. Percent of households used coupons - Overall coupon penetration

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

-- -------------------------------------------------------------------------------------
-- summary
-- -------------------------------------------------------------------------------------

CREATE TABLE household_summary AS
SELECT
    t.household,
    SUM(dollar_sales) AS total_spend,
    COUNT(DISTINCT basket) AS total_transactions,
    SUM(units) AS total_units,
    ROUND(AVG(dbt.days_between_purchases), 2) AS avg_days_between_purchases,
    ROUND(
        COUNT(DISTINCT CASE WHEN coupon = 1 THEN basket END) * 100.0 /
        COUNT(DISTINCT basket), 2
    ) AS couponed_usage_rate
FROM
    transactions t
LEFT JOIN (
    SELECT
        household,
        day - LAG(day) OVER (PARTITION BY household ORDER BY day) AS days_between_purchases
    FROM
        transactions
    GROUP BY
        household,
        day
) dbt ON t.household = dbt.household
WHERE
    dollar_sales > 0 AND units > 0
GROUP BY
    t.household;

\COPY household_summary TO 'C:\Users\JOSHUA\Downloads\household_summary.csv' DELIMITER ',' CSV HEADER;

-- -------------------------------------------------------------------------------------
-- # Part 2: Loyalty & Switching
-- -------------------------------------------------------------------------------------
-- 5. percent of category shoppers loyal to a single brand and ones that switch brands within a category

WITH household_brand_category AS (
    SELECT DISTINCT
        t.household,
        p.commodity AS category,
        p.brand
    FROM
        transactions t
    JOIN product_lookup p ON t.upc = p.upc
), 
brand_count_per_household AS (
    SELECT
        household,
        category,
        COUNT(DISTINCT brand) AS brand_count
    FROM
        household_brand_category
    GROUP BY
        household, category
)
SELECT
    category,
    COUNT(*) AS total_households,
    COUNT(*) FILTER (WHERE brand_count = 1) AS brand_loyals,
    ROUND(COUNT(*) FILTER (WHERE brand_count = 1) * 100.0 / COUNT(*),2) AS brand_loyalty_rate,
	COUNT(*) FILTER (WHERE brand_count > 1) AS switchers,
    ROUND(COUNT(*) FILTER (WHERE brand_count > 1) * 100.0 / COUNT(*), 2) AS switch_rate
FROM
    brand_count_per_household
GROUP BY
    category
ORDER BY
    category asc;

-- -------------------------------------------------------------------------------------
-- 6. Among households who used a coupon to try a brand for the first time, how many re-purchased that brand without a coupon?*/
with purchase_order as (						      /* brand purchase per household */
    select
        t.household,
        p.brand,
        p.commodity,
        t.coupon,
        t.day,
        row_number() over (
            partition by t.household, p.brand
            order by t.day
        ) as purchase_rank
    from
        transactions t
    join product_lookup p on p.upc = t.upc
),
firsttime_coupon_users as (                          /* first-time coupon users */
    select
        household,
        brand,
        commodity,
        day
    from
        purchase_order
    where
        coupon = 1
        and purchase_rank = 1
),
followup_purchasers as (                            /* follow-up purchase without coupon*/
    select
        p.household,
        p.brand,
        p.commodity
    from
        purchase_order p
    join firsttime_coupon_users f
        on p.household = f.household
        and p.brand = f.brand
        and p.day > f.day
    where
        p.coupon = 0
    group by
        p.household,
        p.brand,
        p.commodity
) --  category-wise
select
    f.commodity,
    count(distinct f.household) as total_first_coupon_users,
    count(distinct fp.household) as retained_without_coupon,
    round(
        count(distinct fp.household) * 100.0 / count(distinct f.household),
        2
    ) as retention_rate_percent
from
    firsttime_coupon_users f
left join
    followup_purchasers fp
    on f.household = fp.household
    and f.brand = fp.brand
    and f.commodity = fp.commodity
group by
    f.commodity
order by
    f.commodity asc;

-- -------------------------------------------------------------------------------------
-- #Part 3: Pairing Behavior
-- -------------------------------------------------------------------------------------
-- frequently paired together 

CREATE TABLE brand_pairs AS
WITH household_brand_category AS (
    SELECT DISTINCT
        t.household,
        p.brand,
        p.commodity
    FROM
        transactions t
    JOIN product_lookup p ON t.upc = p.upc
),
brand_pairs AS (
    SELECT
        a.household,
        a.brand AS brand_1,
        a.commodity AS category_1,
        b.brand AS brand_2,
        b.commodity AS category_2
    FROM
        household_brand_category a
    JOIN household_brand_category b
        ON a.household = b.household
        AND a.brand < b.brand
)
SELECT
    category_1,
    brand_1,
    category_2,
    brand_2,
    COUNT(DISTINCT household) AS num_households
FROM
    brand_pairs
GROUP BY
    category_1, brand_1, category_2, brand_2
ORDER BY
    num_households DESC;

-- -------------------------------------------------------------------------------------
-- #Part 4: Coupon Influence
-- -------------------------------------------------------------------------------------
-- 11 . percent of transactions involved coupons, By category & time
*/

CREATE TABLE coupon_influence AS
with transaction_count as (
select 
	count(distinct t.household) as daily_transactions,
	t.day,
	p.commodity as category,
	coalesce(sum(case when coupon =1 then 1 else 0 end),0) as coupon_count,
	coalesce(sum(case when coupon = 0 then 1 else 0 end),0) as without_coupon
from transactions t
	join product_lookup p on t.upc = p.upc
group by p.commodity, t.day
)
select
	day,
	category,
	sum(daily_transactions) as total_households,
	SUM(coupon_count) AS total_couponed,
	SUM(without_coupon) AS total_non_couponed,
	round((sum(coupon_count) * 100.0) / (nullif(sum(coupon_count) + sum(without_coupon),0)),2) as coupon_rate,
	ROUND(SUM(without_coupon) * 100.0 / NULLIF(SUM(coupon_count) + SUM(without_coupon), 0),2) AS without_coupon_rate
	from transaction_count
group by day, category
order by total_households desc, coupon_rate desc
;

-- -------------------------------------------------------------------------------------
--Do high-frequency or low-frequency households use more coupons?
-- setting median value of 63 from part 

WITH total_days AS (
    SELECT household, day
    FROM transactions
    GROUP BY household, day
),
days_between_purchases AS (
    SELECT
        household,
        day - LAG(day) OVER (PARTITION BY household ORDER BY day) AS gap
    FROM total_days
),
avg_days AS (
    SELECT
        household,
        ROUND(AVG(gap), 2) AS avg_days_between_purchases
    FROM days_between_purchases
    WHERE gap IS NOT NULL
    GROUP BY household
),
coupon_usage AS (
    SELECT
        household,
        COUNT(DISTINCT basket) AS total_txns,
        COUNT(DISTINCT CASE WHEN coupon = 1 THEN basket END) AS coupon_txns,
        ROUND(
            COUNT(DISTINCT CASE WHEN coupon = 1 THEN basket END) * 100.0 /
            NULLIF(COUNT(DISTINCT basket), 0),
            2
        ) AS couponed_usage_rate
    FROM transactions
    GROUP BY household
),
combined_summary AS (
    SELECT
        cu.household,
        COALESCE(ad.avg_days_between_purchases, 9999) AS avg_days_between_purchases,
        cu.couponed_usage_rate,
        CASE 
            WHEN COALESCE(ad.avg_days_between_purchases, 9999) < 63.33 THEN 'high-frequency'
            ELSE 'low-frequency'
        END AS frequency_segment
    FROM coupon_usage cu
    LEFT JOIN avg_days ad ON cu.household = ad.household
)
SELECT
    frequency_segment,
    COUNT(*) AS num_households,
    ROUND(AVG(couponed_usage_rate), 2) AS avg_coupon_usage_percent
FROM
    combined_summary
GROUP BY frequency_segment
ORDER BY frequency_segment;


-- "high-frequency"	177555	2.03
-- "low-frequency"	332380	1.48


-- -------------------------------------------------------------------------------------
-- #Part 5: RFM segmentation
-- -------------------------------------------------------------------------------------
-- 14. Recency-Frequency-Monetary (RFM) Segmentation:

CREATE TABLE rfm AS
WITH recency AS (
    SELECT
        household,
        728 - MAX(day) AS recency_days
    FROM
        transactions
    GROUP BY
        household
),
frequency AS (
    SELECT
        household,
        COUNT(DISTINCT basket) AS total_transactions
    FROM
        transactions
    GROUP BY
        household
),
monetary AS (
    SELECT
        household,
        SUM(dollar_sales) AS total_spend
    FROM
        transactions
    GROUP BY
        household
)
SELECT
    r.household,
    r.recency_days,
    f.total_transactions,
    m.total_spend
FROM
    recency r
JOIN frequency f ON r.household = f.household
JOIN monetary m ON r.household = m.household
ORDER BY
    r.recency_days ASC; 

-- -------------------------------------------------------------------------------------
-- 15. Category Penetration: Get total unique households

WITH total_households AS (
    SELECT COUNT(DISTINCT household) AS total FROM transactions
),
category_households AS (
    SELECT
        p.commodity,
        COUNT(DISTINCT t.household) AS category_shoppers
    FROM
        transactions t
        JOIN product_lookup p ON t.upc = p.upc
    GROUP BY
        p.commodity
)
SELECT
    c.commodity,
    c.category_shoppers,
    t.total,
    ROUND(c.category_shoppers * 100.0 / t.total, 2) AS penetration_percent
FROM
    category_households c
    CROSS JOIN total_households t
ORDER BY
    penetration_percent DESC;
/*
"pasta"	411356	509935	80.67
"pasta sauce"	362234	509935	71.04
"syrups"	256476	509935	50.30
"pancake mixes"	130542	509935	25.60
*/

-- 16.  Brand Switching Triggers:
-- Are brand switchers more likely to have used coupons or promotions?

WITH brand_behavior AS (
    SELECT
        t.household,
        p.commodity,
        COUNT(DISTINCT p.brand) AS brand_count,
        COUNT(DISTINCT CASE WHEN t.coupon = 1 THEN t.basket END) AS coupon_txns,
        COUNT(DISTINCT t.basket) AS total_txns
    FROM
        transactions t
        JOIN product_lookup p ON t.upc = p.upc
    GROUP BY
        t.household, p.commodity
),
classified AS (
    SELECT
        *,
        CASE 
            WHEN brand_count > 1 THEN 'Switcher'
            ELSE 'Loyalist'
        END AS shopper_type
    FROM
        brand_behavior
)
SELECT
    commodity,
    shopper_type,
    COUNT(*) AS num_households,
    ROUND(AVG(coupon_txns * 100.0 / NULLIF(total_txns, 0)), 2) AS avg_coupon_usage_percent
FROM
    classified
GROUP BY
    commodity, shopper_type
ORDER BY
    commodity, shopper_type
;
