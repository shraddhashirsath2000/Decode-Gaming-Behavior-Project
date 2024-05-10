Create Database Game_Analysis ;
use game_analysis;

# Import datasets
select * from level_details2;
desc level_details2;
select * from player_details;
DESC Player_details;

alter table player_details modify L1_Status varchar(30);
alter table player_details modify L2_Status varchar(30);
alter table player_details modify P_ID int primary key;
alter table player_details drop myunknowncolumn;

alter table level_details2 drop myunknowncolumn;
alter table level_details2 change timestamp start_datetime datetime;
alter table level_details2 modify Dev_Id varchar(10);
alter table level_details2 modify Difficulty varchar(15);
alter table level_details2 add primary key(P_ID,Dev_id,start_datetime);



# Extract P_ID,Dev_ID,PName and Difficulty_level of all players at level 0

select dev_id,pname,difficulty,level from level_details2
 join
player_details on
level_details2.P_ID = player_details.p_ID
where level=0;

#Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast
--    3 stages are crossed

SELECT L1_code, AVG(Kill_Count) AS Average_Kill_Count
FROM level_details2 inner join player_details
WHERE lives_earned = 2
GROUP BY L1_code
HAVING COUNT(DISTINCT Stages_crossed) >= 3;

# Find the total number of stages crossed at each diffuculty level
-- where for Level2 with players use zm_series devices. Arrange the result
-- in decsreasing order of total number of stages crossed.

 SELECT Difficulty, SUM(Stages_crossed) AS Total_Stages_Crossed
FROM level_details2
WHERE Level = '2' AND Dev_ID like ("zm%")
GROUP BY Difficulty
ORDER BY Total_Stages_Crossed DESC;

# Extract P_ID and the total number of unique dates for those players 
-- who have played games on multiple days.

SELECT P_ID, COUNT(DISTINCT start_datetime) AS Total_Unique_Dates
FROM level_details2
GROUP BY P_ID
HAVING COUNT(DISTINCT start_datetime) > 1;

#  Find P_ID and level wise sum of kill_counts where kill_count
-- is greater than avg kill count for the Medium difficulty.

WITH MediumAvgKill AS (
    SELECT AVG(kill_count) AS AvgKillCount
    FROM level_details2
    WHERE Difficulty = 'Medium'
)
SELECT ld.P_ID, ld.Level, SUM(ld.kill_count) AS Levelwise_Sum_Kill_Count
FROM level_details2 as ld
JOIN MediumAvgKill mak ON ld.kill_count > mak.AvgKillCount
GROUP BY ld.P_ID, ld.Level;

# Find Level and its corresponding Level code wise sum of lives earned 
-- excluding level 0. Arrange in asecending order of level

SELECT Level, L1_Code,L2_Code, SUM(lives_earned) AS Total_Lives_Earned
FROM level_details2,player_details
WHERE Level != 0
GROUP BY Level, L1_code,L2_Code
ORDER BY Level;

# Find Top 3 score based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well.

WITH RankedScores AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY Score) AS ScoreRank
    FROM level_details2
)
SELECT Dev_ID, Score, Difficulty
FROM RankedScores
WHERE ScoreRank <= 3
ORDER BY Dev_ID, ScoreRank;

#  Find first_login datetime for each device id

SELECT Dev_ID, MIN(start_datetime) AS first_login
FROM level_details2
GROUP BY Dev_ID;

# Find Top 5 score based on each difficulty level and Rank them in 
-- increasing order using Rank. Display dev_id as well.

WITH RankedScores AS (
    SELECT Dev_ID, Score, Difficulty,
           dense_rank() OVER (PARTITION BY Difficulty ORDER BY Score) AS Rnk
    FROM level_details2
)
SELECT Dev_ID, Score, Difficulty, Rnk
FROM RankedScores
WHERE Rnk <= 5
ORDER BY Difficulty, Rnk;

# Find the device ID that is first logged in(based on start_datetime) 
-- for each player(p_id). Output should contain player id, device id and 
-- first login datetime.

WITH RankedLogins AS (
    SELECT P_ID, Dev_ID, start_datetime,
           ROW_NUMBER() OVER (PARTITION BY P_ID ORDER BY start_datetime) AS login_rank
    FROM LEVEL_DETAILS2
)
SELECT P_ID, Dev_ID, start_datetime AS first_login_datetime
FROM RankedLogins
WHERE login_rank = 1;

# For each player and date, how many kill_count played so far by the player. That is, the total number of games played -- by the player until that date.
-- a) window function
-- b) without window function

-- a) window function
SELECT
    p_id,
    start_datetime,
    kill_count,
    SUM(kill_count) OVER (PARTITION BY p_id ORDER BY start_datetime ASC) AS cumulative_kills
FROM
    level_details2
ORDER BY
    p_id,
    start_datetime;

-- b) without window function
SELECT 
    ld.p_id,
    ld.start_datetime,
    SUM(ld.kill_count) AS cumulative_kills
FROM 
    level_details2 ld
JOIN 
    player_details pd ON ld.p_id = pd.p_id 
GROUP BY 
    ld.p_id, ld.start_datetime
ORDER BY 
    ld.p_id, ld.start_datetime;


# Find the cumulative sum of stages crossed over `start_datetime` for each `P_ID`, 
-- excluding the most recent `start_datetime`

SELECT 
    P_ID,
    SUM(Stages_crossed) as Cumulative_Stages_crossed
FROM
    level_details2 a
WHERE
    start_datetime < (SELECT MAX(start_datetime) FROM level_details2 b WHERE b.P_ID = a.P_ID)
GROUP BY
    P_ID;


# Extract the top 3 highest sums of scores for each `Dev_ID` and the corresponding `P_ID`.

SELECT 
    a.Dev_ID, 
    a.P_ID, 
    a.Total_Score
FROM 
    (SELECT 
         Dev_ID, 
         P_ID, 
         SUM(score) AS Total_Score
     FROM 
         level_details2
     GROUP BY 
         Dev_ID, P_ID) a
WHERE 
    (SELECT COUNT(*)
     FROM (SELECT Dev_ID, P_ID, SUM(score) AS Total_Score
           FROM level_details2
           GROUP BY Dev_ID, P_ID) b
     WHERE b.Dev_ID = a.Dev_ID AND b.Total_Score > a.Total_Score) < 3
ORDER BY 
    a.Dev_ID, a.Total_Score DESC;
    
# Find players who scored more than 50% of the average score, scored by the sum of 
-- scores for each `P_ID`

SELECT
    ld.P_ID,
    ld.score
FROM
    level_details2 ld
INNER JOIN
    (SELECT
         P_ID,
         AVG(total_score) AS avg_score
     FROM
         (SELECT
              P_ID,
              SUM(score) AS total_score
          FROM
              level_details2
          GROUP BY
              P_ID) AS summed_scores
     GROUP BY
         P_ID) AS avg_scores
ON
    ld.P_ID = avg_scores.P_ID
WHERE
    ld.score > 0.5 * avg_scores.avg_score
ORDER BY
    ld.P_ID;

# Create a stored procedure to find the top `n` `headshots_count` based on each `Dev_ID` 
-- and rank them in increasing order using `Row_Number`. Display the difficulty as well

DELIMITER $$
CREATE PROCEDURE GetNHeadshots(IN top_n INT)
BEGIN
    -- Query to select the top n headshots_count for each Dev_ID ranked by headshots_count in descending order
    SELECT 
        Dev_ID, 
        P_ID, 
        headshots_count, 
        difficulty,
        ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY headshots_count DESC) <= top_n
    FROM 
        level_details2
    ORDER BY 
        Dev_ID;
END$$
DELIMITER ;
CALL GetNHeadshots(2);

