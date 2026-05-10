/*

-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK:  Data Quality Check - user_donation
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:
Проверить таблицу donorsearch.user_donation на:
1. структуру данных;
2. пропуски;
3. технические дубликаты;
4. влияние дублей на сумму donation_count.

Бизнес-смысл:
Перед расчётом активности доноров и бонусов нужно убедиться,
что таблица не завышает метрики из-за дублей.

Ограничения:
Исходные данные на портале изменить нельзя.
Очистка выполняется только SQL-запросами.

*/
-- 1. Быстрый просмотр таблицы
SELECT
	*
FROM
	donorsearch.user_donation ud
LIMIT 20;

-- 2. Изучаем пропуски
SELECT
	COUNT(id) AS id
	-- 6231 строк
	, COUNT(donor_id) AS donor_id
	, COUNT(event_id) AS event_id
	, COUNT(ud.donation_data) AS donation_data
	, COUNT(donation_count) AS donation_count
	-- пропуски
FROM
	donorsearch.user_donation ud
--Пропуски есть donation_count. Необходимо сравнить с донациями в других таблицах;
	
-- 3. Поиск дубликатов
WITH double_line AS (
	SELECT
		*
		, COUNT(*) OVER(
	PARTITION BY donor_id, event_id, donation_data, donation_count
	) AS cnt_double
	FROM
		donorsearch.user_donation ud
)
SELECT 
	*
FROM
	double_line
WHERE
	cnt_double > 1
-- Дубликаты есть;
	
-- 4. Оценка масштаба дубликатов
WITH double_line AS (
	SELECT
		*
		, ROW_NUMBER() OVER(
	PARTITION BY donor_id, event_id, donation_data, donation_count
	ORDER BY id) AS cnt_double
	FROM
		donors`earch.user_donation ud
)
SELECT 
	COUNT(*) AS total_rows
	, COUNT(*) FILTER (
	WHERE
		cnt_double > 1
	) AS cnt_double
	, SUM(donation_count) AS sum_duplicate_donations
	, SUM(donation_count) FILTER (
	WHERE
		cnt_double > 1
	) AS sum_donation_clear
FROM
	double_line
	-- 3031 дубликат из 6231. Трубуется удаление.;/*

ВЫВОДЫ:
1. Обнаружено 3031 технических дубликата (~48.6% строк).
2. Дубли существенно завышают сумму donation_count.
3. Обнаружены пропуски в donation_count.
4. Таблица требует очистки перед расчётом retention/churn.
*/
