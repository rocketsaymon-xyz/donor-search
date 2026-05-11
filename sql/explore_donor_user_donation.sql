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
4. Проверить типы данных;
5. Проверить на выбросы.

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
	
-- Оценка масштаба дубликатов
WITH double_line AS (
	SELECT
		*
		, ROW_NUMBER() OVER(
	PARTITION BY donor_id, event_id, donation_data, donation_count
	ORDER BY id) AS cnt_double
	FROM
		donorsearch.user_donation ud
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

-- 4. Проверяем типы данных в таблице
SELECT 
	column_name
	, data_type
FROM
	information_schema."columns"
WHERE
	table_schema = 'donorsearch'
	AND table_name = 'user_donation'
	-- типы данных соответствуют содержанию;
	
--5. Проверяем на выбросы
SELECT 
	MIN(donation_data) AS min_donation_data
	, MAX(donation_data) AS max_donation_data
	, MIN(donation_count) AS min_donation_count
	, MAX(donation_count) AS max_donation_count
	, AVG(donation_count) AS avg_donation_count
	, PERCENTILE_CONT(0.5) 
		WITHIN GROUP(ORDER BY donation_count) AS median_donation_count
FROM donorsearch.user_donation
-- donation_data, даты донации корректные
-- donation_count количество донаций, нет отрицательного. максимум адеваткный. 
-- Таблица требует очистки перед расчётом retention/churn.. средняя и медиана показывают крайне низкие значения. очень много нулей.

ВЫВОДЫ:
1. Обнаружено 3031 технических дубликата (~48.6% строк).
2. Дубли существенно завышают сумму donation_count.
3. Обнаружены пропуски в donation_count. Таблица требует очистки перед расчётом retention/churn.
4. Типы данных корректны, соответствуют содержанию
5. donation_count. очень много нулевых донаций у доноров. Скорее всего есть группы без донаций. необходимо выяснить причину.
*/