/*

-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK:  Data Quality Check - donation_anon
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:
Проверить таблицу donorsearch.donation_anon на:
1. структуру данных;
2. пропуски;
3. технические дубликаты;
4. Проверить типы данных;
5. Проверить на выбросы.

Бизнес-смысл:
Перед расчётом количества донаций и изучения групп,
что таблица не завышает данные из-за дублей, столбцы содержат актуальные значения без выбросов.

Ограничения:
Исходные данные на портале изменить нельзя.
Очистка выполняется только SQL-запросами.
*/

-- 1.Изучаем данные
SELECT 
	*
FROM donorsearch.donation_anon da
LIMIT 5

--уникальные значения
SELECT 
	DISTINCT donation_status
FROM donorsearch.donation_anon da

-- 2.Изучаем пропуски
SELECT 
	COUNT(id) AS id -- количество сток 245744
	, COUNT(user_id) AS user_id
	, COUNT(blood_class) AS blood_class
	, COUNT(donation_type) AS donation_type
	, COUNT(donation_status) AS donation_status
	, COUNT(donation_place) AS donation_place
FROM donorsearch.donation_anon
-- Пропусков нет

-- 3. Изучаем дубликаты
WITH double_line AS(
SELECT
	*
	, COUNT(*) OVER (
	PARTITION BY user_id, blood_class, donation_date, donation_type, donation_status, donation_place
	) AS cnt
FROM donorsearch.donation_anon
)
SELECT
	*
FROM double_line
WHERE cnt > 1
-- дубликаты есть

-- Считаем дубликаты
WITH double_line AS(
SELECT
	*
	, ROW_NUMBER(*) OVER (
	PARTITION BY user_id, blood_class, donation_date, donation_type, donation_status, donation_place
	ORDER BY user_id) AS cnt
FROM donorsearch.donation_anon
)
SELECT
	COUNT(*) AS all_line -- общее кол-во строк
	, COUNT(*) FILTER (WHERE cnt > 1 ) AS double_line -- строки дубликаты.
FROM double_line
-- дубликатов 19943

-- 4. Проверяем типы данных в таблице
SELECT 
	column_name
	, data_type
FROM information_schema."columns"
WHERE table_schema = 'donorsearch'
	AND table_name = 'donation_anon'
-- типы данных соответствуют содержанию
	
-- 5. Ищем выбросы
SELECT
	MIN(donation_date) AS min_donation_date
	, MAX(donation_date) AS max_donation_date
	, MIN(plan_date) AS min_plan_date
	, MAX(plan_date) AS max_plan_date
	, MIN(donation_added_date) AS min_donation_added_date
	, MAX(donation_added_date) AS max_donation_added_date
FROM donorsearch.donation_anon	
-- donation_date содержит невозможные значения как по максимальным, так и по минимальным. требуется доп изучение и чистка.

/*
ВЫВОДЫ:
1. Данные изучены. grain - 1 строка=1 донация пользвателя: дата, что сдал, тип донации (платная или нет), город, итп;
2. Пропусков нет, есть только один пропуск в столбце city;
3. Явные технические дубликаты обнаружены -19943 строк (около 8% данных), исключаем в staging;
4. Типы данных соответствуют содержанию;
5. Проверка на выбросы показала, donation_date содержит невозможные значения, нужна чистка.
*/	
