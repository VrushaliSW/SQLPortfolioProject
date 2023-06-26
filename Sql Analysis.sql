--Display all records
SELECT * FROM dbo.taxi_zones;
SELECT * FROM DBO.taxi_trips;
SELECT * FROM [dbo].[calendar];

--Add new column for pickup and dropoff time, times_of_day
ALTER TABLE dbo.taxi_trips ADD lpep_pickup_time TIME;
ALTER TABLE dbo.taxi_trips ADD lpep_dropoff_time TIME;
ALTER TABLE dbo.taxi_trips ADD lpep_pickup_date DATE;
ALTER TABLE dbo.taxi_trips ADD lpep_dropoff_date DATE;
ALTER TABLE dbo.taxi_trips ADD times_of_day VARCHAR(20);

--Update the time column
--SELECT CONVERT(TIME, lpep_pickup_datetime, 126) from dbo.taxi_trips;
--SELECT CONVERT(DATE, lpep_pickup_datetime, 126) from dbo.taxi_trips;
UPDATE dbo.taxi_trips SET lpep_pickup_time = CONVERT(TIME, lpep_pickup_datetime, 126);
UPDATE dbo.taxi_trips SET lpep_dropoff_time = CONVERT(TIME, lpep_dropoff_datetime, 126);
UPDATE dbo.taxi_trips SET lpep_pickup_date = CONVERT(DATE, lpep_pickup_datetime, 126);
UPDATE dbo.taxi_trips SET lpep_dropoff_date = CONVERT(DATE, lpep_dropoff_datetime, 126);
--UPDATE dbo.taxi_trips SET [store_and_fwd_flag] = 'N' WHERE [store_and_fwd_flag] != 'N';

--1)Remove trips sent via store and forward
DELETE FROM dbo.taxi_trips WHERE store_and_fwd_flag = 'Y';

--2)Only keep street-hailed trips paid by card or cash with a standard rate
--DELETE FROM dbo.taxi_trips WHERE trip_type <> 1 AND 
DELETE FROM dbo.taxi_trips WHERE trip_type NOT IN (1) OR payment_type NOT IN (1,2) OR RatecodeID <> 1;
--SELECT COUNT(*) FROM dbo.taxi_trips WHERE trip_type = 1 AND payment_type IN (1,2) AND RatecodeID =1;

--3)Remove trips with dates before 2017 or after 2020
DELETE FROM dbo.taxi_trips WHERE lpep_pickup_date < '2017-01-01' OR lpep_pickup_date > '2020-12-31';
--DELETE FROM dbo.taxi_trips WHERE lpep_dropoff_date < '2017-01-01' OR lpep_pickup_date > '2020-12-31'; --0 rows affected

--4)Remove trips with pickup and drop into unknown zones
--Loaction ID = 264 and 265 are unknown zones.
DELETE FROM dbo.taxi_trips WHERE [PULocationID] IN (264, 265) OR [DOLocationID] IN (264, 265);
--SELECT * FROM dbo.taxi_trips WHERE [PULocationID] IN (264, 265) OR [DOLocationID] IN (264, 265);

--5)Trips with no passengers = 1 passenger
UPDATE dbo.taxi_trips SET [passenger_count] = 1 WHERE [passenger_count] = 0 OR [passenger_count] IS NULL;
--SELECT * FROM dbo.taxi_trips WHERE [passenger_count] = 0;

--6)If pick date/ time is after drop off, swap them
UPDATE dbo.taxi_trips SET [lpep_pickup_time] = [lpep_dropoff_time], 
						  [lpep_pickup_date] = [lpep_dropoff_date], 
						  [lpep_dropoff_time] = [lpep_pickup_time],
						  [lpep_dropoff_date] = [lpep_pickup_date]
WHERE [lpep_pickup_datetime] > [lpep_dropoff_datetime];
--SELECT * FROM dbo.taxi_trips WHERE [lpep_pickup_datetime] > [lpep_dropoff_datetime];

--7)Remove trips larger than a day
DELETE FROM dbo.taxi_trips WHERE DATEDIFF(day, [lpep_pickup_datetime], [lpep_dropoff_datetime]) = 1 AND 
DATEDIFF(second, [lpep_pickup_datetime], [lpep_dropoff_datetime]) >= 86400 OR
DATEDIFF(day, [lpep_pickup_datetime], [lpep_dropoff_datetime]) > 1;
--SELECT [lpep_pickup_datetime], [lpep_dropoff_datetime], DATEDIFF(day, [lpep_pickup_datetime], [lpep_dropoff_datetime]) as days, DATEDIFF(second, [lpep_pickup_datetime], [lpep_dropoff_datetime]) as seconds from dbo.taxi_trips;

--8)Remove trips with distance and fare amount = 0
DELETE FROM dbo.taxi_trips WHERE [trip_distance] = 0 AND [fare_amount] = 0;
--SELECT * FROM dbo.taxi_trips WHERE [trip_distance] = 0 AND [fare_amount] = 0; 

--9)Trips with fare taxes & subcharges as negative shoulds be positive
UPDATE dbo.taxi_trips SET [fare_amount] = ABS([fare_amount]), [extra] = ABS([extra]), [mta_tax] = ABS([mta_tax]),
[tip_amount] = ABS([tip_amount]), [tolls_amount] = ABS([tolls_amount]), [improvement_surcharge] = ABS([improvement_surcharge]),
[total_amount] = ABS([total_amount]);

--10)For trips with fare amount, no distance, distance = (Fare*2.5)/2.5;
UPDATE dbo.taxi_trips SET [trip_distance] = ([fare_amount]*2.5)/2.5 WHERE [trip_distance] = 0;

--11)For trips with distance but no fare amount, fare_amount = 2.5+(distance*2.5)
UPDATE dbo.taxi_trips SET [fare_amount] = 2.5+([trip_distance]*2.5) WHERE [fare_amount] = 0;

--12)Group time of day 
UPDATE dbo.taxi_trips SET times_of_day = CASE 
	WHEN (DATEPART(Hour,[lpep_pickup_time]) >= 6 AND DATEPART(Hour,[lpep_pickup_time]) < 12) THEN 'Morning'
	WHEN DATEPART(Hour,[lpep_pickup_time]) >= 12 AND DATEPART(Hour,[lpep_pickup_time]) < 18 THEN 'Afternoon'
	WHEN DATEPART(Hour,[lpep_pickup_time]) >= 18 AND DATEPART(Hour,[lpep_pickup_time]) < 24 THEN 'Evening'
	ELSE 'Night'
END;


--Data Analysis:
--Get start date and end date for that week no and respective year.
SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2017 AND FiscalWeekOfYear = 10 ORDER BY DATE ASC;
SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2017 AND FiscalWeekOfYear = 10 ORDER BY DATE DESC;

--Taxi_Trips data for specified year and week
WITH Weekly_Taxi_Trip
AS(
	SELECT * FROM dbo.taxi_trips WHERE [lpep_pickup_date] 
	BETWEEN (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE ASC) AND 
	        (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE DESC)     
)
SELECT * FROM Weekly_Taxi_Trip;

--What's the average number of trips?
WITH Weekly_Taxi_Trip
AS(
	SELECT COUNT(*) as No_of_Trips,[lpep_pickup_date]  FROM dbo.taxi_trips WHERE [lpep_pickup_date] 
	BETWEEN (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE ASC) AND 
			(SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE DESC)
	GROUP BY lpep_pickup_date
)
SELECT AVG(No_of_Trips) as Average_Number_Of_Trips FROM Weekly_Taxi_Trip;


--What's the average fare per trip?
WITH Weekly_Taxi_Trip
AS(
	SELECT *  FROM dbo.taxi_trips WHERE [lpep_pickup_date] 
	BETWEEN (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE ASC) AND 
	        (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE DESC)
)
SELECT AVG([fare_amount]) as Average_Fare_Amount, AVG([total_amount]) as Average_Total_Cost FROM Weekly_Taxi_Trip;

--What's the average distance traveled per trip?
WITH Weekly_Taxi_Trip
AS(
	SELECT * FROM dbo.taxi_trips WHERE [lpep_pickup_date] 
	BETWEEN (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE ASC) AND 
		    (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE DESC)
)
SELECT AVG([trip_distance]) as Average_Trip_Distance FROM Weekly_Taxi_Trip;

--What will be the most popular pick-up locations?
SELECT TOP 1 b.[Borough], b.[Zone] FROM (SELECT * , DENSE_RANK() OVER(ORDER BY [PULocationID]) as Row_No FROM dbo.taxi_trips WHERE [lpep_pickup_date] 
	BETWEEN (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE ASC) AND 
	        (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE DESC)) a
	JOIN [dbo].[taxi_zones] b
ON a.[PULocationID] = b.[LocationID]
GROUP BY a.[PULocationID], b.[Borough] , b.[Zone]
ORDER BY COUNT(Row_No) DESC;


--What will be the most popular drop-off locations?
SELECT TOP 1 b.[Borough], b.[Zone] FROM (SELECT * , DENSE_RANK() OVER(ORDER BY [PULocationID]) as Row_No FROM dbo.taxi_trips WHERE [lpep_pickup_date] 
	BETWEEN (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE ASC) AND 
	        (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 10 ORDER BY DATE DESC)) a
	JOIN [dbo].[taxi_zones] b
ON a.[DOLocationID] = b.[LocationID]
GROUP BY a.[DOLocationID], b.[Borough], b.[Zone]
ORDER BY COUNT(Row_No) DESC;

--Which days of the week will be busiest?
SELECT TOP 2 a.[lpep_pickup_date], b.[DayName] FROM (SELECT [lpep_pickup_date] , DENSE_RANK() OVER(ORDER BY [lpep_pickup_date]) as Row_No FROM dbo.taxi_trips WHERE [lpep_pickup_date] 
	BETWEEN (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 2 ORDER BY DATE ASC) AND 
	        (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 2 ORDER BY DATE DESC)) a
	JOIN [dbo].[calendar] b
ON a.[lpep_pickup_date] = b.[Date]
GROUP BY [lpep_pickup_date], b.[DayName]
ORDER BY COUNT(Row_No) DESC;

--Which times of the days will be busiest?
SELECT TOP 2 [times_of_day] FROM (SELECT [times_of_day] , DENSE_RANK() OVER(ORDER BY [times_of_day]) as Row_No FROM dbo.taxi_trips WHERE [lpep_pickup_date] 
	BETWEEN (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 3 ORDER BY DATE ASC) AND 
	        (SELECT TOP 1 DATE FROM dbo.calendar WHERE FiscalYear = 2020 AND FiscalWeekOfYear = 3 ORDER BY DATE DESC)) a
GROUP BY [times_of_day]
ORDER BY COUNT(Row_No) DESC;


--View created for visualization in Power BI
CREATE VIEW Taxi_Trip_2020_View AS
SELECT T.*, C.FiscalWeekOfYear as week_of_year FROM dbo.taxi_trips T
JOIN [dbo].[calendar] C
ON T.[lpep_pickup_date] = C.[Date]
WHERE C.[FiscalYear] = 2020;