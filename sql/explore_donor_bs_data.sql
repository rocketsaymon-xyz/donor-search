/*

-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK:  Data Quality Check - bs_data
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:
Проверить таблицу donorsearch.bs_data на:
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

-- 1. Изучаем данные
SELECT
	*
FROM donorsearch.bs_data bd 
LIMIT 10
-- данные изучили. таблица в целом не нужна. количество донаций по больницам, можно посчитать по таблице донаций.

-- 2.Считаем пропуски
SELECT
	COUNT(bd.blood_center_id ) AS blood_center_id -- строк 1065
	, COUNT(bd.city ) AS city
	, COUNT(bd.country ) AS country
	, COUNT(bd.donation_count ) AS donation_count	
	, COUNT(bd.donor_count ) AS donor_count
FROM donorsearch.bs_data bd 
--пропусков нет

-- Изучаем дубликаты
WITH double_line AS(
SELECT
	*
	, COUNT(*) OVER(
	PARTITION BY blood_center_id, city, country, donation_count, donor_count
	) AS cnt_double
FROM donorsearch.bs_data bd 
)
SELECT
	*
FROM double_line
WHERE cnt_double > 1
LIMIT 10
--дубликаты отсутствуют


/*
ВЫВОДЫ:
1. в EDA можно обойтись без этой таблицы
*/	