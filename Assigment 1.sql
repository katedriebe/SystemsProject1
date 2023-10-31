USE films; 


# I created a star sschema with three dimension tables and a central fact table. I choose this structure because it is fast at computing aggregations and because the ETL process that I proformed in python can easily be streamlined into the schema.  
# Creat a table called DimMovie. This table describes the movies with attributes like title, year, directors, certification, and genres. It serves as a dimension to provide context about movies.
CREATE TABLE DimMovie (
    MovieID INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255),
    year INT,
    directors VARCHAR(255),
    certification VARCHAR(255),
    genres VARCHAR(255)
);

#Insert data into DimMovie table
INSERT INTO DimMovie (title, year, directors, certification, genres)
SELECT 
    p.title,
    p.year,
    r.directors,
    p.certification, 
    pf.genres 
FROM popular AS p 
JOIN profit AS pf ON p.title = pf.title AND p.year = pf.year
JOIN ratings AS r ON p.title = r.title AND p.year = r.year;

#Create a table called DimRatings. This table holds the ratings from various platforms (rottentomatoes and imdb_rating). It serves as a dimension to provide context about the ratings a movie received.
CREATE TABLE DimRatings (
    RatingID INT AUTO_INCREMENT PRIMARY KEY,
    rottentomatoes INT,
    imdb_rating DECIMAL(3,1)    
);

#Insert data into DimRatings table
INSERT INTO DimRatings (rottentomatoes, imdb_rating)
SELECT 
    r.rottentomatoes, 
    r.imdb_rating    
FROM ratings AS r;

#Create table called DimProfit. This table provides financial data related to movies, such as budget, domestic gross, foreign gross, and world gross. It serves as a dimension to understand a movie's financial metrics.
CREATE TABLE DimProfit (
    ProfitID INT AUTO_INCREMENT PRIMARY KEY,
    budget DECIMAL(15,2),
    domesticgross DECIMAL(15,2),
    foreigngross DECIMAL(15,2),
    worldgross DECIMAL(30,2)
);

#Insert data into DimProfit table
INSERT INTO DimProfit (budget, domesticgross, foreigngross, worldgross)
SELECT 
    pf.budget, 
    pf.domesticgross, 
    pf.foreigngross, 
    pf.worldgross 
FROM profit AS pf;


# Create table called FactMovieMetrics. This is the central fact table that connects the dimensional tables. Each row in this fact table represents a metric record for a movie. In this schema, it doesn't have measurable facts (like sales quantity or total revenue), but rather it links the various dimensions together. I did this so I could quickly gather information about a particular movie's ratings and financials in a single joined query.
CREATE TABLE FactMovieMetrics (
    MetricID INT AUTO_INCREMENT PRIMARY KEY,
    MovieID INT,
    RatingID INT,
    ProfitID INT,
    FOREIGN KEY (MovieID) REFERENCES DimMovie(MovieID),
    FOREIGN KEY (RatingID) REFERENCES DimRatings(RatingID),
    FOREIGN KEY (ProfitID) REFERENCES DimProfit(ProfitID)
);

INSERT INTO FactMovieMetrics (MovieID, RatingID, ProfitID)
SELECT 
    m.MovieID,
    r.RatingID,
    p.ProfitID
FROM 
    popular pop 
JOIN DimMovie m ON pop.title = m.title AND pop.year = m.year
JOIN ratings rat ON pop.title = rat.title AND pop.year = rat.year
JOIN DimRatings r ON rat.rottentomatoes = r.rottentomatoes AND rat.imdb_rating = r.imdb_rating
JOIN profit pf ON pop.title = pf.title AND pop.year = pf.year
JOIN DimProfit p ON pf.budget = p.budget AND pf.domesticgross = p.domesticgross AND pf.foreigngross = p.foreigngross AND pf.worldgross = p.worldgross;
#Calculation: 

# Average world gross for movies grouped by genre
# From this statement reveals that action movies have the highest average world gross and that mystries have the lowest
# Film studios, producers, and investors can use this data to make informed decisions about where to invest their resources. 
SELECT 
    genres,
    AVG(worldgross) AS average_world_gross
FROM profit
GROUP BY genres;

# The total amount spent on movie budgets, the total worldwide gross, and the net profit (gross minus budget) for movies of each year.
# From this statement it is revealed that the movie industry was the most profitable in 2013 but the best rated movies were realeased in 2007, the industry proformed its worst finically in 2010
# Film studios, producers, and investors can use this data can determine how profitable movies were as a collective group for each year which can help inform fucture investments. 
SELECT 
    m.year,
    AVG(r.imdb_rating) AS avg_imdb_rating,
    SUM(p.budget) AS total_budget,
    SUM(p.worldgross) AS total_worldgross,
    SUM(p.worldgross) - SUM(p.budget) AS net_profit
FROM 
    FactMovieMetrics fmm
JOIN DimMovie m ON fmm.MovieID = m.MovieID
JOIN DimRatings r ON fmm.RatingID = r.RatingID
JOIN DimProfit p ON fmm.ProfitID = p.ProfitID
GROUP BY m.year
ORDER BY m.year DESC;

# Calculated the average ratings and total profit for each genre
# The statement show that some interesting information like how horror grosses larger outside of the US while comedy is the inverse. 
#  Film studios, producers, and investors could use it to determine what type of genres receive the most audience aproval and how that how much money the movie makes 
SELECT 
    m.genres,
    AVG(r.rottentomatoes) AS avg_rotten_tomatoes_rating,
    AVG(r.imdb_rating) AS avg_imdb_rating,
    SUM(p.budget) AS total_budget,
    SUM(p.domesticgross) AS total_domesticgross,
    SUM(p.foreigngross) AS total_foreigngross,
    SUM(p.worldgross) AS total_worldgross
FROM 
    FactMovieMetrics fmm
JOIN DimMovie m ON fmm.MovieID = m.MovieID
JOIN DimRatings r ON fmm.RatingID = r.RatingID
JOIN DimProfit p ON fmm.ProfitID = p.ProfitID
GROUP BY m.genres
ORDER BY total_worldgross DESC;



#View of movie directors the average total earnings from worldwide gross, and the average IMDb ratings for their movies.
# This statment demostrates that Shane Black's films has the highest average woldwide gross out of all directors inclduing in the dataset, but has one of the lowest IMDB rating averages
# Film studios, producers, and investors could use this caculation to determine which dictor they should hire. 
SELECT 
    dm.directors,    
    SUM(dp.worldgross) / COUNT(dm.title) AS avg_worldgross_earnings,
    AVG(dr.imdb_rating) AS average_imdb_rating
FROM FactMovieMetrics fmm
JOIN DimMovie dm ON fmm.MovieID = dm.MovieID
JOIN DimRatings dr ON fmm.RatingID = dr.RatingID
JOIN DimProfit dp ON fmm.ProfitID = dp.ProfitID
GROUP BY dm.directors
ORDER BY avg_worldgross_earnings DESC;
