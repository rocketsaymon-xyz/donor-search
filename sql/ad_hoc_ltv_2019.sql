/*
-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK:  12-month donation-based LTV by 2019 monthly cohorts
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:
1. Оценить LTV доноров по когортам за 2019. Период измерения 365 дней.

Бизнес-смысл:
Отследить как меняется бизнес метрика LTV по когортам в периоде, можно понять эффективность мероприятий.

Ограничения:
Исходные данные на портале изменить нельзя.
Очистка выполняется только SQL-запросами.
*/

WITH donation_anon_double_line AS ( -- нумеруем дубликаты
SELECT 
	*
	, ROW_NUMBER() OVER(-- нумеруем дубликаты
	PARTITION BY user_id, blood_class, donation_date, plan_date, donation_type, city, donation_status, donation_added_date
	ORDER BY id) AS cnt_double
FROM donorsearch.donation_anon da
WHERE (donation_date BETWEEN '1975-01-01' AND '2020-12-31')  -- фильтруем сразу дату
	AND (donation_status IN ('Без справки', 'На модерации', 'Принята'))-- фильтр по существующим датам
)
, donation_anon_clear AS (
SELECT
	region
	, user_id 
	, donation_date
	, MIN(donation_date)  -- мин дата для определения когорты.
		OVER(PARTITION BY user_id) AS cohort_date 
	, DATE_TRUNC('month', MIN(donation_date) 
		OVER (PARTITION BY user_id))::date  AS cohort_month
FROM donation_anon_double_line
WHERE cnt_double = 1 -- оставляем 
)
, ltv_12m AS (
SELECT 
	user_id
	, cohort_month
	, COUNT(DISTINCT user_id) AS users_cnt
	, COUNT(*) AS user_ltv_12m
FROM donation_anon_clear 
WHERE cohort_month >= '2019-01-01'AND 
	cohort_month < '2020-01-01' AND
	donation_date < cohort_date + INTERVAL '365 days' 
GROUP BY user_id, cohort_month
)
SELECT
	cohort_month
	, SUM(users_cnt) AS users_cohort
	, ROUND(AVG(user_ltv_12m), 2) AS ltv_users
FROM ltv_12m
GROUP BY cohort_month
ORDER BY cohort_month;

/*
ВЫВОДЫ:
1. Среднее количество донаций за один год чуть около 2.
	- кровь можно сдавать 4 раза женщинам и 5 раз мужчинам.
	- а плазму 140 раз в год;
	Есть возможности для роста.
2. Сильная сезонность/каналы привлечения влияют;
3. Размер когорты падает, но качество растет (LTV повышается с2 до 3) → рост “в глубину”;
4. возможные причины улудшения LTV:
	- улучшение работы с донорами;
	- повышения качества привлечения трафика;
	- изменения бонусной программы;
	- изменения поведения новых пользователей.
   
 Рекомендации:
1. разделить донации крови от всех остальных, выставить минимальные потребности;
2. работать с удержанием доноров, повышая уровень их лояльности;
3. разьяснять возможности по донорству:
	- количества донаций в год
	- что донор может сдавать на станциях;
4. присылать сообщение донору, что его кровь спасла кому-то жизнь.
5. активные пользователи могут привлечь других активных доноров, добавить им мотивацию за приведи друга.
*/
