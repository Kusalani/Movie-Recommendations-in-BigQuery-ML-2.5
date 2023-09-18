-- Explore the data
SELECT
  COUNT(DISTINCT userId) numUsers,
  COUNT(DISTINCT movieId) numMovies,
  COUNT(*) totalRatings
FROM
  movies.movielens_ratings
  
-- Examine the first few movies using the query:
SELECT
  *
FROM
  movies.movielens_movies_raw
WHERE
  movieId < 5

-- Parse the genres into an array and rewrite the results into a table named movielens_movies
CREATE OR REPLACE TABLE
  movies.movielens_movies AS
SELECT
  * REPLACE(SPLIT(genres, "|") AS genres)
FROM
  movies.movielens_movies_raw

 -- Evaluate a trained model created using collaborative filtering
CREATE OR REPLACE MODEL movies.movie_recommender 
  OPTIONS (model_type='matrix_factorization', user_col='userId', item_col='movieId', rating_col='rating', l2_reg=0.2, num_factors=16) 
  AS SELECT userId, movieId, rating 
  FROM movies.movielens_ratings

-- View metrics for the trained model
SELECT * FROM ML.EVALUATE(MODEL `cloud-training-prod-bucket.movies.movie_recommender`)

-- Make recommendations
SELECT
  *
FROM
  ML.PREDICT(MODEL `cloud-training-prod-bucket.movies.movie_recommender`,
    (
    SELECT
      movieId,
      title,
      903 AS userId
    FROM
      `movies.movielens_movies`,
      UNNEST(genres) g
    WHERE
      g = 'Comedy' ))
ORDER BY
  predicted_rating DESC
LIMIT
  5  
/*This result includes movies the user has already seen and rated in the past.*/

  
 /* the top predicted ratings didn’t include any of the movies the user has already seen.*/
SELECT
  *
FROM
  ML.PREDICT(MODEL `cloud-training-prod-bucket.movies.movie_recommender`,
    (
    WITH
      seen AS (
      SELECT
        ARRAY_AGG(movieId) AS movies
      FROM
        movies.movielens_ratings
      WHERE
        userId = 903 )
    SELECT
      movieId,
      title,
      903 AS userId
    FROM
      movies.movielens_movies,
      UNNEST(genres) g,
      seen
    WHERE
      g = 'Comedy'
      AND movieId NOT IN UNNEST(seen.movies) ))
ORDER BY
  predicted_rating DESC
LIMIT
  5

-- Apply customer targeting
  SELECT
    *
  FROM
    ML.PREDICT(MODEL `cloud-training-prod-bucket.movies.movie_recommender`,
      (
      WITH
        allUsers AS (
        SELECT
          DISTINCT userId
        FROM
          movies.movielens_ratings )
      SELECT
        96481 AS movieId,
        (
        SELECT
          title
        FROM
          movies.movielens_movies
        WHERE
          movieId=96481) title,
        userId
      FROM
        allUsers ))
  ORDER BY
    predicted_rating DESC
  LIMIT
    100

-- Perform batch predictions for all users and movies
  SELECT
    *
  FROM
    ML.RECOMMEND(MODEL `cloud-training-prod-bucket.movies.movie_recommender`)
  LIMIT 
    100000
