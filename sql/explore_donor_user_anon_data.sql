/*

-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK:  Data Quality Check - user_anon_data
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:
Проверить таблицу donorsearch.user_anon_data на:
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

-- 1. Изучаем данные.
SELECT
	*
FROM
	donorsearch.user_anon_data uad
LIMIT 20;

-- 2. Считаем количество строк и пропуски в столбцах.
SELECT 
	COUNT(id) AS all_line
	, COUNT(gender) AS gender
	, COUNT(birth_date)AS birth_date
	, COUNT(region) AS region
	, COUNT(blood_type) AS blood_type
	, COUNT('kell-faktor') AS kell_faktor
	, COUNT(whole_blood) AS whole_blood
	, COUNT(honorary_donor) AS honorary_donor
	, COUNT(withdrawal_from_donation) AS withdrawal_from_donation
	, COUNT(whole_blood_count) AS whole_blood_count
	, COUNT(registration_date) AS registration_date
	, COUNT(donations_before_registration) AS donations_before_registration
	, COUNT(last_activity) AS last_activity
	, COUNT(email_is_specified) AS email_is_specified
	, COUNT(phone_specified) AS phone_specified
	, COUNT(autho_vk) AS autho_vk
	, COUNT(icon_20) AS icon_20
	, COUNT(icon_100) AS icon_100
	, COUNT(donations_of_time_registration) AS donations_of_time_registration
	, COUNT(count_bonuses_taken) AS count_bonuses_taken
FROM
	donorsearch.user_anon_data uad;
-- Пропуски есть во всех столбцах, кроме id, kell_faktor, whole_blood, whole_blode_count, registration_date и булевых значений.



-- 3. Находим дубликаты явные в user_anon_data.
WITH user_anon_data_double_line AS (
	SELECT
		*
		,ROW_NUMBER() OVER(
		PARTITION BY id, gender, birth_date, whole_blood, registration_date, count_bonuses_taken
				ORDER BY id) AS cnt_double
	FROM donorsearch.user_anon_data uad)
SELECT 
	*
FROM user_anon_data_double_line
WHERE cnt_double > 1
	--явные дубликатов по отсутствуют;
	

-- 4. Проверить типы данных 
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'donorsearch'
  AND table_name = 'user_anon_data'
 -- данные в таблице корректные

-- 5. Проверить на выбросы 
 SELECT
 	uad.gender
 	, MIN(registration_date) AS min_registration_date 
 	, MAX(registration_date) AS registration_date 
 	, MIN(birth_date) AS min_birth_date
 	, MAX(birth_date) AS max_birth_date
 	, MIN(donations_of_time_registration) AS min_donations_of_time_registration
 	, MAX(donations_of_time_registration) AS max_donations_of_time_registration
 	, MIN(last_activity) AS min_last_activity
 	, MAX(last_activity) AS max_last_activity
 	, MIN(count_bonuses_taken) AS  min_count_bonuses_taken
 	, MAX(count_bonuses_taken) AS max_count_bonuses_taken
	, PERCENTILE_CONT(0.5)
		WITHIN GROUP (ORDER BY count_bonuses_taken) AS perc_count_bonuses_taken
 	, MIN(confirmed_donations) AS min_confirmed_donations
 	, MAX(confirmed_donations) AS max_confirmed_donations
	, PERCENTILE_CONT(0.5)
		WITHIN GROUP (ORDER BY confirmed_donations) AS perc_confirmed_donations
FROM donorsearch.user_anon_data uad
GROUP BY gender
-- registration_date. Минимальное значение 2018-04-09 (с него надо делать изучение данных о системных донациях.
-- registration_date. Максимальное значение 2023-11-28 (дата выгрузки отчета)
-- birth_date. Есть выбросы: дни рождения из будущего, и люди с возрастом почти 150 лет, что не может быть.
-- donations_of_time_registration. Минимальное. отрицательных значений нет.
-- donations_of_time_registration. Максимальное в целом ок*
-- last_activity. последняя дата активности совпадает с датой выгрузки. все ок
-- count_bonuses_taken. минимум. Отрицательных значений нет
-- confirmed_donations. минимум. Отрицательных значений нет;
-- confirmed_donations. Максмум,  ок.*
	--*в таблице не только кровь, но и плазма. За жизнь плазму можно сдать свыше 900 раз. текущие значения меньше этой цифры.


/*
ВЫВОДЫ:
1. Явные технические дубликаты не обнаружены;
2. Пропуски есть во всех столбцах, кроме id, kell_faktor, whole_blood, whole_blode_count, registration_date и булевых значений;
3. Не все зарегистрированные пользователи имеют подтверждённые донации;
4. Типы данных соответствуют содержанию;
5. Проверка на выбросы:
	- registration_date. Период 2018-04-09  - 2023-11-28
	- birth_date. Необходима очистка данных. по верхней и нижней границы возраста. (возраст 65 лет ограничения по донациям)
*/