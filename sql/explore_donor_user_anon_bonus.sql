/*

-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK:  Data Quality Check - user_anon_bonus
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:
Проверить таблицу donorsearch.user_anon_bonus на:
1. структуру данных;
2. пропуски;
3. технические дубликаты;
4. Проверить типы данных;
5. Проверить на выбросы.

Бизнес-смысл:
Перед расчётом активности доноров и использованию бонусов нужно убедиться,
что таблица не завышает метрики из-за дублей, какие столбцы можно использовать (содержат достаточно количество данных) без выбросов.

Ограничения:
Исходные данные на портале изменить нельзя.
Очистка выполняется только SQL-запросами.
*/

-- 1. Изучаем данные
SELECT
	*
FROM
	donorsearch.user_anon_bonus uab
LIMIT 10
-- date_of_use - не использовать для анализа;

-- 2. Считаем пропуски
SELECT
	COUNT(*) AS total_rows
	, COUNT(id) AS id_count
	, ROUND(100.0 * (COUNT(*) - COUNT(id)) / COUNT(*), 2) AS id_null_pct
	, COUNT(user_id) AS user_id_count
	, ROUND(100.0 * (COUNT(*) - COUNT(user_id)) / COUNT(*), 2) AS user_id_null_pct
	, COUNT(user_bonus_count) AS user_bonus_count_count
	, ROUND(100.0 * (COUNT(*) - COUNT(user_bonus_count)) / COUNT(*), 2) AS user_bonus_count_null_pct
	, COUNT(donation_count) AS donation_count_count
	, ROUND(100.0 * (COUNT(*) - COUNT(donation_count)) / COUNT(*), 2) AS donation_count_null_pct
	, COUNT(partner) AS partner_count
	, ROUND(100.0 * (COUNT(*) - COUNT(partner)) / COUNT(*), 2) AS partner_null_pct
	, COUNT(bonus_name) AS bonus_name_count
	, ROUND(100.0 * (COUNT(*) - COUNT(bonus_name)) / COUNT(*), 2) AS bonus_name_null_pct
	, COUNT(date_of_use) AS date_of_use_count
	, ROUND(100.0 * (COUNT(*) - COUNT(date_of_use)) / COUNT(*), 2) AS date_of_use_null_pct
	, COUNT(country) AS country_count
	, ROUND(100.0 * (COUNT(*) - COUNT(country)) / COUNT(*), 2) AS country_null_pct
	, COUNT(region) AS region_count
	, ROUND(100.0 * (COUNT(*) - COUNT(region)) / COUNT(*), 2) AS region_null_pct
	, COUNT(city) AS city_count
	, ROUND(100.0 * (COUNT(*) - COUNT(city)) / COUNT(*), 2) AS city_null_pct
FROM
donorsearch.user_anon_bonus uab;
-- Пропуски присутствуют в столбцах date_of_use, country, city

-- 3. Изучаем дубликаты
WITH double_line AS( 
SELECT 
	*
	, COUNT(*) OVER (
	PARTITION BY user_id, user_bonus_count, donation_count, partner, bonus_name, date_of_use, city
	) AS cnt_double
FROM donorsearch.user_anon_bonus uab
)
SELECT 
	*
FROM
	double_line
WHERE
	cnt_double > 1;

--Считаем дубликаты
WITH double_line AS( 
SELECT 
	*
	, ROW_NUMBER(*) OVER (
	PARTITION BY user_id, user_bonus_count, donation_count, partner, bonus_name, date_of_use, city
	ORDER BY user_id) AS cnt_double
FROM donorsearch.user_anon_bonus uab
)
SELECT 
	COUNT(*)
	, COUNT(*) FILTER (
	WHERE
		cnt_double > 1
	)
FROM
	double_line
	-- Дубликатов всего 3 из 21108 строк. Требуется удаление
	
-- 4. Проверяем типы данных в столбцах
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'donorsearch'
  AND table_name = 'user_anon_bonus'
 -- данные в таблице корректные	

-- 5.  Проверить на выбросы
SELECT
 	MIN(date_of_use) AS min_date_of_use 
 	, MAX(date_of_use) AS max_date_of_use 
 	, MIN(donation_count) AS  min_donation_count
 	, MAX(donation_count) AS max_donation_count
	, PERCENTILE_CONT(0.5)
		WITHIN GROUP (ORDER BY donation_count) AS perc_donation_count
 	, MIN(user_bonus_count) AS min_user_bonus_count
 	, MAX(user_bonus_count) AS max_user_bonus_count
	, PERCENTILE_CONT(0.5)
		WITHIN GROUP (ORDER BY user_bonus_count) AS perc_user_bonus_count
FROM donorsearch.user_anon_bonus uab
-- date_of_use, не использовать
-- donation_count. минимальных значение отрицательных нет, максимальное корректное.
-- donation_count, Медиана 5;
-- user_bonus_count. Отрицательных значений нет. Но странно, что есть бонусы у тех людей, кто не имеет донации.

/*
ВЫВОДЫ:
1. Данные изучены. grain - 1 строка=1 пользователь, его количество донаций, бонусов и даты.
2. Пропуски присутствуют в столбцах date_of_use, country, city;
3. Явные технические дубликаты обнаружены -3 строки (менее 1% данных), требуют удаления;
4. Типы данных соответствуют содержанию;
5. Проверка на выбросы:
	- требуется проверка корректности начисления бонусов, они есть у тех доноров, кто не имеет донаций.
*/