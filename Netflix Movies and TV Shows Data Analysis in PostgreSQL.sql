 ---------------------------------- Netflix Data Analysis Using SQL -----------------------------------

-- dataset_file = netflix_dataset.csv  (8807 records)
-- 12 columns
-- show_id	type	title	director	cast	country	date_added	release_year	rating	duration	listed_in	description


-- create table

DROP TABLE IF EXISTS netflix;

CREATE TABLE netflix 
(
	show_id	VARCHAR(6),
	type VARCHAR(10),
	title VARCHAR(150),        -- in excel run =MAX(LEN(C2:C8807)) = 104
	director VARCHAR(250),     -- in excel run =MAX(LEN(D2:D8807)) = 208
	casts VARCHAR(1000),       -- in excel run =MAX(LEN(E2:E8807)) = 771
	country	VARCHAR(150),      -- in excel run =MAX(LEN(F2:F8807)) = 123
	date_added	VARCHAR(50),   -- it is in text in excel
	release_year INT,
	rating	VARCHAR(10),
	duration VARCHAR(15),
	listed_in VARCHAR(100),    -- intentionally, first kept 25, then import failed, then change it to 100
	description VARCHAR(250)   -- in excel run =MAX(LEN(L2:L8807)) = 250
);

-- though 'type' and 'cast' both are keywords in PostgreSQL
-- it is giving error for 'cast' only while creating table
-- so, changing cast to casts, keeping 'type' as same

-- after import, check data
SELECT * FROM netflix; -- all columns are there

-- check for total data
SELECT COUNT(*) FROM netflix; -- 8807 rows


-- -------------------------------- 15 Business Problems & Solutions ---------------------------------

-- 1. Count the number of Movies vs TV Shows

SELECT type, COUNT(*) as Total_content
FROM netflix
GROUP BY type


-- 2. Find the most common rating for movies and TV shows

SELECT * FROM netflix;

WITH CTE AS (
	SELECT type, rating, COUNT(rating) AS cnt
	, RANK() OVER(PARTITION BY type ORDER BY COUNT(rating) DESC) AS rn
	FROM netflix
	GROUP BY type, rating
	--ORDER BY type, cnt DESC
)
SELECT type, rating as most_common_rating
FROM CTE
WHERE rn = 1;


-- 3. List all movies released in a specific year (e.g., 2020)

SELECT * FROM netflix;
SELECT date_added, release_year FROM netflix LIMIT 5;

-- answer
SELECT title
FROM netflix 
WHERE type = 'Movie' 
AND release_year = 2020;


-- 4. Find the top 5 countries with the most content on Netflix

SELECT * FROM netflix LIMIT 5;

SELECT country, COUNT(*) as total_count
FROM netflix
GROUP BY country
ORDER BY 2 DESC
LIMIT 5; -- getting rows with multiple countries

-- Method 1: Using STRING_TO_ARRAY() and UNNEST()

SELECT country from netflix;

SELECT country, STRING_TO_ARRAY(country, ',') as new_country 
from netflix; -- 8807 records

SELECT country, UNNEST(STRING_TO_ARRAY(country, ',')) as new_country 
from netflix; -- 10019 records

-- answer
SELECT TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) as new_country, COUNT(show_id) as total_content
FROM netflix
GROUP BY TRIM(UNNEST(STRING_TO_ARRAY(country, ',')))
ORDER BY 2 DESC
LIMIT 5; -- United States is coming two times, we need to TRIM before GROUP BY


-- Method 2: USING REGEXP_SPLIT_TO_TABLE()

SELECT show_id, type, TRIM(REGEXP_SPLIT_TO_TABLE(country, ','))
FROM netflix

-- answer
SELECT TRIM(REGEXP_SPLIT_TO_TABLE(country, ',')) AS country, COUNT(show_id) as total_content
FROM netflix
GROUP BY TRIM(REGEXP_SPLIT_TO_TABLE(country, ','))
ORDER BY 2 DESC
LIMIT 5;


-- 5. Identify the longest movie

SELECT type, title, duration FROM netflix WHERE type = 'Movie';

select * from (
SELECT title, duration, LENGTH(duration), LENGTH(LTRIM(duration)), LTRIM(duration), POSITION(' ' in LTRIM(duration)) 
FROM netflix
WHERE type = 'Movie'
) t
WHERE LENGTH(duration)<> LENGTH(LTRIM(duration));

-- Method 1:

SELECT title as movie, duration 
FROM
(
	SELECT 
		title,
		CAST(SUBSTRING(duration, 1, POSITION(' ' in LTRIM(duration)) - 1) AS INT) AS duration,
		ROW_NUMBER() OVER(ORDER BY 
							CAST(SUBSTRING(duration, 1, POSITION(' ' in LTRIM(duration)) - 1) AS INT) DESC
						 ) AS rn
	FROM netflix
	WHERE type = 'Movie' AND duration IS NOT NULL
) t
WHERE rn = 1; -- 320

-- Method 2: Using SPLIT_PART() from comment section

select * 
from 
 (
	select distinct title as movie,
  	split_part(duration,' ',1):: numeric as duration 
  	from netflix
  	where type ='Movie'
 ) as subquery
where duration = (select max(split_part(duration,' ',1):: numeric ) from netflix); -- 320


-- 6. Find content added in the last 5 years

SELECT show_id, type, title, date_added FROM netflix;

-- 3 methods to change data type of 'data_added' column
SELECT show_id, type, title, date_added, date_added::DATE FROM netflix;
SELECT show_id, type, title, date_added, CAST(date_added AS DATE) FROM netflix;
SELECT show_id, type, title, date_added, TO_DATE(date_added, 'Month DD, YYYY') from netflix;

-- Method 1: 

SELECT show_id, type, title, date_added
, DATE_PART('year', CURRENT_DATE) - DATE_PART('year', date_added::DATE ) 
FROM netflix
WHERE DATE_PART('year', CURRENT_DATE) - DATE_PART('year', date_added::DATE ) <= 5; -- 5393 rows

-- Method 2: correct answer

SELECT CURRENT_DATE - INTERVAL '5 years'

SELECT date_added, TO_DATE(date_added, 'Month DD, YYYY'), date_added:: DATE
FROM netflix

-- answer
SELECT *
FROM netflix
WHERE date_added:: DATE > CURRENT_DATE - INTERVAL '5 years'; -- 4040 rows


-- 7. Find all the movies/TV shows by director 'Rajiv Chilaka'!

SELECT *
FROM netflix
WHERE director = 'Rajiv Chilaka'; -- 19 rows


SELECT *
FROM netflix
WHERE director LIKE '%Rajiv Chilaka%'; -- 22 rows (but in PostgreSQL, it does case-sensitive search)

-- answer
SELECT *
FROM netflix
WHERE director ILIKE '%Rajiv Chilaka%'; -- 22 rows (for case-insensitive search)


-- 8. List all TV shows with more than 5 seasons

SELECT * FROM netflix where type = 'TV Show';

-- Method 1: Using LEFT()

SELECT title, duration
FROM netflix 
where type = 'TV Show'
AND LEFT(duration, POSITION(duration,' ') - 1):: INT > 5; 

-- Method 2:  Using SPLIT_PART()

SELECT SPLIT_PART('A,B,C,D', ',',1); -- A

SELECT title, duration
FROM netflix 
where type = 'TV Show'
AND SPLIT_PART(duration,' ',1):: numeric > 5; -- 99 rows


-- 9. Count the number of content items in each genre

SELECT * FROM netflix

-- Method 1: Using REGEXP_SPLIT_TO_TABLE()

WITH CTE AS (
	SELECT show_id, TRIM(REGEXP_SPLIT_TO_TABLE(listed_in, ',')) as genre
	FROM netflix
)
SELECT genre, COUNT(*) as Total_count
FROM CTE
GROUP BY genre; -- 42 rows

-- Method 2: Using STRING_TO_ARRAY() & UNNEST()

SELECT show_id, STRING_TO_ARRAY(listed_in, ',') as genre
FROM netflix;

SELECT genre, COUNT(show_id)
FROM 
(
	SELECT show_id, TRIM(UNNEST(STRING_TO_ARRAY(listed_in, ','))) as genre
	FROM netflix
) t
GROUP BY genre; -- 42 rows



-- 10. Find each year and the average numbers of content release in India on netflix. 
--     return top 5 year with highest avg content release!

SELECT * FROM netflix;

WITH CTE AS (
	SELECT 
		show_id,
		DATE_PART('year', date_added::DATE) as release_year,
		TRIM(REGEXP_SPLIT_TO_TABLE(country, ',')) AS country
	FROM netflix 
)
SELECT 
	release_year,
	ROUND(
	COUNT(show_id) * 100.0 / ( SELECT COUNT(*) FROM CTE WHERE country = 'India' )
		,2) AS avg_release
FROM CTE
WHERE country = 'India'
GROUP BY release_year
ORDER BY 2 DESC
LIMIT 5;



-- 11. List all movies that are documentaries

SELECT * FROM netflix 
WHERE type = 'Movie' 
AND listed_in ILIKE '%Documentaries%'; -- 869 rows


-- 12. Find all content without a director

SELECT * FROM netflix 
WHERE director IS NULL; -- 2634 rows



-- 13. Find how many movies actor 'Salman Khan' appeared in last 10 years!

SELECT CURRENT_DATE - INTERVAL '10 years';

SELECT * FROM netflix
WHERE casts ILIKE '%Salman Khan%' -- 20 rows
AND type = 'Movie'
AND release_year > EXTRACT(year FROM CURRENT_DATE) - 10; -- 2 rows



-- 14. Find the top 10 actors who have appeared in the highest number of movies produced in India.

WITH CTE AS (
	SELECT show_id, TRIM(UNNEST((STRING_TO_ARRAY(casts, ',')))) AS actors 
	from netflix 
	WHERE country LIKE '%India%'
)
SELECT actors, COUNT(*) as no_of_appearance
FROM CTE
GROUP BY actors
ORDER BY 2 DESC
LIMIT 10; 



-- 15. Categorize the content based on the presence of the keywords 'kill' and 'violence' in 
--     the description field. Label content containing these keywords as 'Bad' and all other 
--     content as 'Good'. Count how many items fall into each category.


SELECT * from netflix
WHERE description ILIKE '%kill%' 
OR description ILIKE '%violence%';

WITH CTE AS (
	SELECT *
	, CASE WHEN description ILIKE '%kill%' OR description ILIKE '%violence%' THEN 'Bad'
			ELSE 'Good'
	  END AS category
	from netflix
)
SELECT category, COUNT(*) total_content
FROM CTE
GROUP BY category;