/*

-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK:  Data Quality Check - donation_plan
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:
Проверить таблицу donorsearch.donation_plan на:
1. структуру данных;
2. пропуски;
3. технические дубликаты;
4. Проверить типы данных;
5. Проверить на выбросы.

Бизнес-смысл:
Перед расчётом результатовности записей на донороство нужно убедиться,
что таблица не завышает данные из-за дублей, столбцы содержат актуальные значения без выбросов.

Ограничения:
Исходные данные на портале изменить нельзя.
Очистка выполняется только SQL-запросами.
*/

-- 1. Изучаем данные donation_plan
SELECT 
	*
FROM donorsearch.donation_plan dp 
LIMIT 10;

-- 2. Считаем пропуски
SELECT
	COUNT(*) AS all_line --кол-во строк
	, COUNT(user_id) AS user_id
	, ROUND(100.0 * (COUNT(*) - COUNT(user_id)) / COUNT(*), 2) AS user_id_null_pct
	, COUNT(blood_class) AS blood_class
	, ROUND(100.0 * (COUNT(*) - COUNT(blood_class)) / COUNT(*), 2) AS blood_class_null_pct
	, COUNT(donation_date) AS donation_date
	, ROUND(100.0 * (COUNT(*) - COUNT(donation_date)) / COUNT(*), 2) AS donation_date_null_pct
	, COUNT(plan_date) AS plan_date
	, ROUND(100.00 * (COUNT(*) - COUNT(plan_date)) / COUNT(*), 2) AS plan_date_null_pct
	, COUNT(donation_type) AS donation_type
	, ROUND(100.0 * (COUNT(*) - COUNT(donation_type)) / COUNT(*), 2) AS donation_type_null_pct
	, COUNT(donation_place) AS donation_place
	, ROUND(100.0 * (COUNT(*) - COUNT(donation_place)) / COUNT(*), 2) AS donation_place_null_pct
	, COUNT(confirmation) AS confirmation
	, ROUND(100.0 * (COUNT(*) - COUNT(confirmation)) / COUNT(*), 2) AS confirmation_null_pct
	, COUNT(plan_status) AS plan_status
	, ROUND(100.0 * (COUNT(*) - COUNT(plan_status)) / COUNT(*), 2) AS plan_status_null_pct
FROM donorsearch.donation_plan
-- пропусков нет;

-- 3. Изучаем дубликаты
WITH double_line AS (
SELECT
	*
	, COUNT(*) OVER(
	PARTITION BY user_id, blood_class, donation_date, plan_date, confirmation, donation_type, donation_place, plan_status
	) AS cnt_double
FROM donorsearch.donation_plan dp)
SELECT 
	*
FROM double_line
WHERE cnt_double > 1
-- Дубликаты есть

-- Считаем дубликаты
WITH double_line AS (
SELECT 
	*
	, ROW_NUMBER() OVER(
	PARTITION BY user_id, blood_class, donation_date, plan_date, confirmation, donation_type, donation_place, plan_status
	ORDER BY user_id) AS cnt_double
FROM donorsearch.donation_plan dp )
SELECT 
	COUNT(*)
	, COUNT(*) FILTER (WHERE cnt_double > 1) AS cnt_double
FROM double_line
-- 929 дублей из 27720 строк

-- 4. Проверяем типы данных в таблице
SELECT 
	column_name
	, data_type
FROM information_schema.columns
WHERE table_schema = 'donorsearch'
	AND table_name = 'donation_plan'
-- типы данных соответствуют содержанию
	
-- 5. Ищем выбросы
SELECT
	MIN(donation_date) AS min_donation_date
	, MAX(donation_date) AS max_donation_date
	, MIN(plan_date) AS min_plan_date
	, MAX(plan_date) AS max_plan_date
FROM donorsearch.donation_plan;
-- Даты в столбцах donation_date, plan_date корректные 
	
/*
ВЫВОДЫ:
1. Данные изучены. grain - 1 строка=1 запись поользвателя на сдачу: его даты записи, дата планируемой донации
	, тип донации платно/белсплатно, город, статус;
2. Пропусков нет, есть только один пропуск в столбце city;
3. Явные технические дубликаты обнаружены -929 строк (около 3% данных), исключаем в staging;
4. Типы данных соответствуют содержанию;
5. Проверка на выбросы показала, что нет перекосов по датам
*/	