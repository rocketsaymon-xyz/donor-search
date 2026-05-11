/*
-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK:   Identify stations with the highest first-time donor churn
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:  Найти ТОП 10 худший станций, который имеют самый высокий first time churn rate
		
Бизнес-смысл:
Чтобы повышать количество донаций через возврат доноров, необходимо выявлять слабые звенья -
	худшие станции, которые не нравятся пользователям. А уже потом работать с ними.

Ограничения:
Исходные данные на портале изменить нельзя.
Очистка выполняется только SQL-запросами.
*/


--минимальная дата 1975-01-01
--Максмальная дата 2023-11-28

WITH donation_anon_double_line AS(
SELECT 
	user_id
	, donation_date
	, donation_type
	, donation_place
	, city
	, donation_status
	, ROW_NUMBER() OVER(--нумеруем дубликаты
	PARTITION BY user_id, donation_date, donation_type, donation_place, donation_status, blood_class
	ORDER BY id) AS cnt_double
FROM donorsearch.donation_anon da
WHERE (donation_date BETWEEN '1975-01-01' AND '2023-11-28')--фильтр по существующим датам
	AND (donation_status IN ('Без справки', 'На модерации', 'Принята'))-- фильтр по статусам, оставляем только подтвержденные донации
)
, donation_anon_clear AS (
	SELECT
		city
		, donation_place
		, user_id
		, donation_type
		, donation_status
		, donation_date
		, COUNT(donation_date) OVER(-- считаем количество донаций на одного пользователя
	PARTITION BY user_id) AS number_donation
		, ROW_NUMBER() OVER (
			-- при условии, что не может быть две донации в один день.
	PARTITION BY user_id
		ORDER BY
			donation_date
		) AS number_donation_date
	FROM
		donation_anon_double_line
	WHERE
		cnt_double = 1
)
, first_churn_rate AS (
	SELECT
		city
		, donation_place
		, ROUND(COUNT(user_id) FILTER (WHERE number_donation = 1)::NUMERIC
    	/ COUNT(user_id) * 100,
    	2) AS first_time_churn_rate
	FROM
		donation_anon_clear
	WHERE
		number_donation_date = 1
		AND donation_place NOT IN ('Выездная акция')
	GROUP BY
		city
		, donation_place
	HAVING
		COUNT(user_id) >= 50
)
, anti_top_10_churn_rate AS(
SELECT
	*
FROM first_churn_rate
ORDER BY first_time_churn_rate DESC
LIMIT 10)
SELECT
	*
FROM
	anti_top_10_churn_rate
UNION ALL
SELECT
	'ALL' AS city
	, 'MEDIAN' AS donation_place
	, ROUND(
        (percentile_cont(0.5) 
     WITHIN GROUP (ORDER BY first_time_churn_rate))::NUMERIC,
    2)AS first_time_churn_rate
	-- процент доноров, которые не вернулись после первой донации
FROM
	first_churn_rate;

/*
 ВЫВОДЫ:
1. Медиана по churn_rate среди станций донации 52,56%. каждый второй донор уходит после первой донации;
2. Есть станции анти лидеры. В Якутске, Ярославля, Щёлково. 7 человек из 10 больше не возвращаются в программу
	после первой донации;
3.  В отчете станции по переливанию, которые посетили от 50 доноров.

Рекомендации:
1. В EDA анализе выбрать срок для CHURN rate, что будет считаться уходом;
2. Протестировать retention-механики через A/B тесты с новыми донорами и отследить изменения:
	- добавить им благодарственные письма (другую не материальную мотивацию);
	- После определение сроков CHURN потери клиентов, настроить выборку user_id  для повторного приглашения после первой рекомендации;
3. По станциям-антилидерам провести качественную проверку:
   - опрос доноров;
   - анализ времени ожидания;
   - анализ отказов и статусов;
   - сравнение процесса с лучшими станциями.
*/
	