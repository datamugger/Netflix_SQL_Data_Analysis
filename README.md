# Netflix Movies and TV Shows Data Analysis using SQL

![](https://github.com/datamugger/Netflix_SQL_Data_Analysis/blob/main/logo.png)

## Overview
This project involves a comprehensive analysis of Netflix's movies and TV shows data using SQL. The goal is to extract valuable insights and answer various business questions based on the dataset. The following README provides a detailed account of the project's objectives, business problems, solutions, findings, and conclusions.

## Objectives

- Analyze the distribution of content types (movies vs TV shows).
- Identify the most common ratings for movies and TV shows.
- List and analyze content based on release years, countries, and durations.
- Explore and categorize content based on specific criteria and keywords.

## Dataset

The data for this project is sourced from the Kaggle dataset:

- **Dataset Link:** [Movies Dataset](https://www.kaggle.com/datasets/shivamb/netflix-shows?resource=download)

## Schema

```sql
DROP TABLE IF EXISTS netflix;
CREATE TABLE netflix
(
    show_id      VARCHAR(5),
    type         VARCHAR(10),
    title        VARCHAR(250),
    director     VARCHAR(550),
    casts        VARCHAR(1050),
    country      VARCHAR(550),
    date_added   VARCHAR(55),
    release_year INT,
    rating       VARCHAR(15),
    duration     VARCHAR(15),
    listed_in    VARCHAR(250),
    description  VARCHAR(550)
);
```

## Business Problems and Solutions

### 1. Count the Number of Movies vs TV Shows

```sql
SELECT type, COUNT(*) as Total_content
FROM netflix
GROUP BY type
```

**Objective:** Determine the distribution of content types on Netflix.

### 2. Find the Most Common Rating for Movies and TV Shows

```sql
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
```

**Objective:** Identify the most frequently occurring rating for each type of content.

### 3. List All Movies Released in a Specific Year (e.g., 2020)

```sql
SELECT title
FROM netflix 
WHERE type = 'Movie' 
AND release_year = 2020;
```

**Objective:** Retrieve all movies released in a specific year.

### 4. Find the Top 5 Countries with the Most Content on Netflix

```sql
-- Using STRING_TO_ARRAY() & UNNEST()

SELECT 
	TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) as country, 
	COUNT(show_id) as total_content
FROM netflix
GROUP BY TRIM(UNNEST(STRING_TO_ARRAY(country, ',')))
ORDER BY 2 DESC
LIMIT 5; -- United States is coming two times, we need to TRIM before GROUP BY
```

```sql
-- Using REGEXP_SPLIT_TO_TABLE()

SELECT
  TRIM(REGEXP_SPLIT_TO_TABLE(country, ',')) AS country,
  COUNT(show_id) as total_content
FROM netflix
GROUP BY TRIM(REGEXP_SPLIT_TO_TABLE(country, ','))
ORDER BY 2 DESC
LIMIT 5;
```

**Objective:** Identify the top 5 countries with the highest number of content items.

### 5. Identify the Longest Movie

```sql
-- Using SPLIT_PART()

select * 
from 
 (
	select distinct title as movie,
  	split_part(duration,' ',1):: numeric as duration 
  	from netflix
  	where type ='Movie'
 ) as subquery
where duration = (select max(split_part(duration,' ',1):: numeric ) from netflix);
```

```sql
-- Using SUBSTRING()

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
WHERE rn = 1;
```

**Objective:** Find the movie with the longest duration.

### 6. Find Content Added in the Last 5 Years

```sql
SELECT *
FROM netflix
WHERE TO_DATE(date_added, 'Month DD, YYYY') >= CURRENT_DATE - INTERVAL '5 years';
```

**Objective:** Retrieve content added to Netflix in the last 5 years.

### 7. Find All Movies/TV Shows by Director 'Rajiv Chilaka'

```sql
SELECT *
FROM netflix
WHERE director ILIKE '%Rajiv Chilaka%';
```

**Objective:** List all content directed by 'Rajiv Chilaka'.

### 8. List All TV Shows with More Than 5 Seasons

```sql
-- Using SPLIT_PART()

SELECT *
FROM netflix
WHERE type = 'TV Show'
AND SPLIT_PART(duration, ' ', 1)::INT > 5;
```

```sql
-- Using LEFT()

SELECT title, duration
FROM netflix 
where type = 'TV Show'
AND LEFT(duration, POSITION(duration,' ') - 1):: INT > 5; 
```

**Objective:** Identify TV shows with more than 5 seasons.

### 9. Count the Number of Content Items in Each Genre

```sql
SELECT genre, COUNT(show_id)
FROM 
(
	SELECT show_id, TRIM(UNNEST(STRING_TO_ARRAY(listed_in, ','))) as genre
	FROM netflix
) t
GROUP BY genre;
```

```sql
-- Using REGEXP_SPLIT_TO_TABLE()

WITH CTE AS (
	SELECT
      show_id,
      TRIM(REGEXP_SPLIT_TO_TABLE(listed_in, ',')) as genre
	FROM netflix
)
SELECT genre, COUNT(*) as Total_count
FROM CTE
GROUP BY genre;
```

**Objective:** Count the number of content items in each genre.

### 10.Find each year and the average numbers of content release in India on netflix. Return top 5 year with highest avg content release!

```sql
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
```

**Objective:** Calculate and rank years by the average number of content releases by India.

### 11. List All Movies that are Documentaries

```sql
SELECT * 
FROM netflix
WHERE type = 'Movie'
AND listed_in ILIKE '%Documentaries';
```

**Objective:** Retrieve all movies classified as documentaries.

### 12. Find All Content Without a Director

```sql
SELECT * 
FROM netflix
WHERE director IS NULL;
```

**Objective:** List content that does not have a director.

### 13. Find How Many Movies Actor 'Salman Khan' Appeared in the Last 10 Years

```sql
SELECT * 
FROM netflix
WHERE casts ILIKE '%Salman Khan%'
AND release_year > EXTRACT(YEAR FROM CURRENT_DATE) - 10;
```

**Objective:** Count the number of movies featuring 'Salman Khan' in the last 10 years.

### 14. Find the Top 10 Actors Who Have Appeared in the Highest Number of Movies Produced in India

```sql
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
```

**Objective:** Identify the top 10 actors with the most appearances in Indian-produced movies.

### 15. Categorize Content Based on the Presence of 'Kill' and 'Violence' Keywords

```sql
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
```

**Objective:** Categorize content as 'Bad' if it contains 'kill' or 'violence' and 'Good' otherwise. Count the number of items in each category.

## Findings and Conclusion

- **Content Distribution:** The dataset contains a diverse range of movies and TV shows with varying ratings and genres.
- **Common Ratings:** Insights into the most common ratings provide an understanding of the content's target audience.
- **Geographical Insights:** The top countries and the average content releases by India highlight regional content distribution.
- **Content Categorization:** Categorizing content based on specific keywords helps in understanding the nature of content available on Netflix.

This analysis provides a comprehensive view of Netflix's content and can help inform content strategy and decision-making.



## Author - Animesh Mishra

This project is part of my portfolio, showcasing the SQL skills essential for data analyst roles. If you have any questions, feedback, or would like to collaborate, feel free to get in touch!
