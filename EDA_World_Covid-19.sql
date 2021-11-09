--1.Recorded Covid cases/infection rate across the timeline starting Jan 28, 2020

---a. Current infected % of the population by countries


SELECT continent, location, date, population, total_cases, (total_cases/population*100) AS current_infected_rate
FROM `daportfolio.Covid_data.Covid Deaths` 
WHERE continent IS NOT NULL 
ORDER BY location, date DESC


---b. Weekly infection rate of the population by countries


WITH WeeklyExtract AS (
SELECT continent, location, population, date, EXTRACT(year FROM date) AS Year, EXTRACT(week FROM date) AS WeekofYear, total_cases, new_cases
FROM `daportfolio.Covid_data.Covid Deaths` 
WHERE continent IS NOT NULL 
ORDER BY location, date
)
SELECT continent, location, Year, WeekofYear, CAST(SUM(new_cases)/MAX(population)*100 AS NUMERIC) AS Weekly_infected_rate, CAST(MAX(total_cases)/MAX(population)*100 AS NUMERIC) AS Current_total_infection_rate
FROM WeeklyExtract
GROUP BY continent, location, Year, WeekofYear
ORDER BY location, Year, WeekofYear



---c. Monthly infection rate of population by countries


WITH MonthlyExtract AS (
SELECT continent, location, population, date, EXTRACT(year FROM date) AS Year, EXTRACT(month FROM date) AS Month, total_cases, new_cases
FROM `daportfolio.Covid_data.Covid Deaths` 
WHERE continent IS NOT NULL 
ORDER BY location, date
)
SELECT continent, location, Year, Month, CAST(SUM(new_cases)/MAX(population)*100 AS NUMERIC) AS Monthly_infected_rate, CAST(MAX(total_cases)/MAX(population)*100 AS NUMERIC) AS Current_total_infection_rate
FROM MonthlyExtract
--WHERE location = 'India'
GROUP BY continent, location, Year, Month
ORDER BY location, Year, Month



---d. Ranking countries as per the latest monthly new cases detected


WITH MonthlyExtract AS (
SELECT continent, location, population, date, EXTRACT(year FROM date) AS Year, EXTRACT(month FROM date) AS Month, total_cases, new_cases
FROM `daportfolio.Covid_data.Covid Deaths` 
WHERE continent IS NOT NULL 
ORDER BY location, date
),
current_year AS (
SELECT *
FROM MonthlyExtract 
WHERE Year = (SELECT MAX(Year) FROM MonthlyExtract)
),
latest_month AS (
SELECT * 
FROM current_year 
WHERE Month = (SELECT MAX(Month) FROM current_year)
)
SELECT continent, location, Year, Month, SUM(new_cases) AS latest_month_new_cases, CAST(SUM(new_cases)/MAX(population)*100 AS NUMERIC) AS Monthly_infected_rate
FROM latest_month  
GROUP BY continent, location, Year, Month
ORDER BY latest_month_new_cases DESC 



---e. Monthly % increase in new cases


WITH MonthlyExtract AS (
SELECT continent, location, population, date, EXTRACT(year FROM date) AS Year, EXTRACT(month FROM date) AS Month, new_cases
FROM `daportfolio.Covid_data.Covid Deaths` 
WHERE continent IS NOT NULL 
ORDER BY location, date
)
,
monthly_rate AS (
SELECT continent, location, Year, Month, CAST(SUM(new_cases)/MAX(population)*100 AS NUMERIC) AS Monthly_infected_rate
FROM MonthlyExtract
GROUP BY continent, location, Year, Month
ORDER BY location, Year, Month
)
,
previous_month_rate AS (
    SELECT * , LAG(Monthly_infected_rate,1) OVER(ORDER BY location, Year, Month ) AS Infected_previous_month
    FROM monthly_rate 
)
SELECT * , CASE
WHEN  Infected_previous_month = 0 THEN 0
ELSE ((Monthly_infected_rate - Infected_previous_month)/Infected_previous_month*100) 
END AS percent_change
FROM previous_month_rate 
--WHERE location = 'India'
ORDER BY location, Year, Month



---f. Ranking countries as per total cases


WITH case_count AS(
SELECT continent, location, MAX(total_cases) AS Total_cases
FROM `daportfolio.Covid_data.Covid Deaths` 
WHERE continent IS NOT NULL  
GROUP BY continent, location
)
SELECT *, DENSE_RANK() OVER(ORDER BY Total_cases DESC) AS Ranking
FROM case_count
ORDER BY Total_cases DESC



---g. Ranking countries as per maximum infected rate


SELECT continent, location,CAST(MAX(total_cases)/MAX(population)*100 AS NUMERIC) AS maximum_infected_rate
FROM `daportfolio.Covid_data.Covid Deaths` 
WHERE continent IS NOT NULL  
GROUP BY continent, location
ORDER BY maximum_infected_rate DESC



--2. Recorded hospitalizations, deaths across the timeline from Jan 28, 2020

---a. % hospitalized compared to total cases 


SELECT continent, location, CAST(SUM(CAST(weekly_hosp_admissions AS NUMERIC))/ MAX(total_cases)*100 AS NUMERIC) AS hosp_admissions_per_cases
FROM `daportfolio.Covid_data.Covid Deaths` 
WHERE continent IS NOT NULL 
GROUP BY continent, location
ORDER BY hosp_admissions_per_cases DESC



--b. % admitted to the ICU compared to total cases


SELECT continent, location, CAST(SUM(CAST(weekly_icu_admissions AS NUMERIC))/ MAX(total_cases)*100 AS NUMERIC) AS ICU_admissions_per_cases
FROM `daportfolio.Covid_data.Covid Deaths` 
WHERE continent IS NOT NULL 
GROUP BY continent, location
ORDER BY ICU_admissions_per_cases DESC



---c. Monthly trend - % deaths compared to the total cases


SELECT continent, location, Year, Month, CAST(MAX(total_deaths)/MAX(total_cases)*100 AS NUMERIC) AS deaths_per_cases
FROM (
SELECT continent, location, date, EXTRACT(year FROM date) AS Year, EXTRACT(month FROM date) AS Month, total_cases, total_deaths
FROM `daportfolio.Covid_data.Covid Deaths` 
)
WHERE continent IS NOT NULL 
--AND location = 'India' 
GROUP BY continent, location, Year, Month
ORDER BY location, Year, Month



---- Overall % of deaths compared to the total cases


SELECT continent, location, CAST(MAX(total_deaths)/MAX(total_cases)*100 AS NUMERIC) AS deaths_per_cases
FROM `daportfolio.Covid_data.Covid Deaths` 
WHERE continent IS NOT NULL  
GROUP BY continent, location
ORDER BY deaths_per_cases DESC



--3. Population vaccinated

---a. Percentage of the population at least partially vaccinated


WITH vaccination_count AS (
SELECT va.continent, va.location, va.date, va.population, va.new_vaccinations
, MAX(CAST(va.total_vaccinations AS INT64)) OVER (Partition by va.Location Order by va.location, va.Date) as current_population_vaccinated
FROM `daportfolio.Covid_data.Covid Vaccines`va
JOIN `daportfolio.Covid_data.Covid Deaths` da
	ON va.location = da.location
	AND va.date = da.date
WHERE va.continent IS NOT NULL
ORDER BY 2,3 DESC
)
SELECT *, (current_population_vaccinated/population)*100 AS percent_population_vaccinated
FROM vaccination_count
--where location = 'India'



--b. % of population atleast partially vaccinated - Monthly trend line


WITH population_vaccinated AS (
SELECT va.continent, va.location, da.Year, da.Month, MAX(va.population) AS population, MAX(va.new_vaccinations) AS new_vaccinations
, MAX(CAST(va.total_vaccinations AS INT64)) as current_population_vaccinated
FROM `daportfolio.Covid_data.Covid Vaccines`va
JOIN 
(SELECT *, EXTRACT(Year FROM date) AS Year, EXTRACT(Month FROM date) AS Month 
FROM `daportfolio.Covid_data.Covid Deaths`) da
	ON va.location = da.location
	AND va.date = da.date
WHERE va.continent IS NOT NULL
GROUP BY va.continent, va.location, da.Year, da.Month
ORDER BY 2,3 DESC,4 DESC
)
SELECT *, (current_population_vaccinated/population)*100 AS percent_vaccinated
FROM population_vaccinated
--WHERE location = 'India'

