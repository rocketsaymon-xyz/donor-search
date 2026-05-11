/*

-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK:  Prepare analytical datasets for Python EDA
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель: подготовить данные для EDA в Python
1. очистка от дубликатов;
2. выбрать необходимые столбцы
3. соединить таблицы
4. фильтр по значениям
	
Бизнес-смысл:
Необходимо уменьшить объем данных и выполнить базовые запросы перед выгрузкой. Чтобы сделать обработку информацию дешевле/
Удалить технические дубликаты.

Ограничения:
Исходные данные на портале изменить нельзя.
Очистка выполняется только SQL-запросами.
*/

/*
 * Готовим данные для Python EDA таблицы user_anon_data, donation_anon, user_donation, events

	user_anon_data
id
gender
birth_date
region
blood_type
honorary_donor
icon_20
icon_100
registration_date
last_activity - посл. активность на сайте
email_is_specified
phone_specified
autho_vk
autho_google
confirmed_donations
count_bonuses_taken - использованные бонусы

	donation_anon
user_id
blood_class
donation_date
plan_date
donation_type
donation_place
donation_status

	user_donation
donor_id
event_id
donation_data
donation_count

	events
organization_id
event_begin
event_end
reg_count
city	
*/

--объединяем таблицы user_donation, events
WITH user_donation_double_line AS (
	SELECT
		*
		--нумеруем дубликаты
		, ROW_NUMBER() OVER(
			PARTITION BY donor_id, event_id, donation_data, donation_count
			ORDER BY id) AS cnt_double
	FROM
		donorsearch.user_donation ud
)
, user_donation_clear AS (
	SELECT 
		donor_id
		, event_id
		, donation_data
		, donation_count
	FROM
		user_donation_double_line
	WHERE
		cnt_double = 1
)
, events_double_line AS(
	SELECT 
		*
		-- нумеруем дубликаты
		, ROW_NUMBER() OVER(
			PARTITION BY organization_id, event_begin, event_end, reg_count, city 
			ORDER BY id) AS cnt_double
	FROM donorsearch.events e 
)
, events_clear AS (
	SELECT
		id
		, event_begin
		, event_end
		, reg_count
		, city
	FROM
		events_double_line
	WHERE
		cnt_double = 1
)
SELECT 
	donor_id
	, udc.event_id
	, event_begin
	, event_end
	, city
	, reg_count AS events_all_donor
	, donation_data
	, donation_count
FROM
	user_donation_clear udc
LEFT JOIN events_clear ec ON 
	udc.event_id = ec.id
ORDER BY
	donor_id
-- Готово

-- Последняя активность на сайте: 2023-11-28
--Подготовка данных donation_anon
WITH donation_anon_double_line AS (
	-- убираем дубликаты из user_donation
	SELECT
		user_id
		, blood_class
		, donation_date
		, donation_type
		, donation_status
		, donation_place
		-- первая донация
		, MIN(donation_date) OVER(PARTITION BY user_id) AS first_donation_date	
		, ROW_NUMBER() OVER (
			--Нумеруем строки по дубликатам по столбцам
               PARTITION BY user_id
			, blood_class
			, donation_date
			, donation_type
			, donation_status
			, donation_place
		ORDER BY
			id
		) AS rn
	FROM
		donorsearch.donation_anon
)
, donation_anon_clear AS (
	SELECT
		--
		user_id
		, blood_class
		, donation_date
		, donation_type
		, donation_status
		, donation_place
		, first_donation_date
	FROM
		donation_anon_double_line
	WHERE
		rn = 1
		--оставляем только первый ранг. сбрасываем дубли
)
SELECT
	*
FROM
	donation_anon_clear
WHERE
	donation_status IN (
		'Принята', 'На модерации', 'Без справки'
	);
-- Готово


-- Подготовка данных user_anon_data
WITH donation_anon_double_line AS (
	-- убираем дубликаты из user_donation
	SELECT
		user_id
		, donation_status
		, donation_date
		, ROW_NUMBER() OVER (
			--Нумеруем строки по дубликатам по столбцам
               PARTITION BY user_id
			, blood_class
			, donation_date
			, donation_type
			, donation_status
			, donation_place
		ORDER BY
			id
		) AS rn
	FROM
		donorsearch.donation_anon
)
, donation_anon_clear AS (
	SELECT
		user_id
		, MIN(donation_date) AS first_donation_date
	FROM
		donation_anon_double_line
	--оставляем только первый ранг. сбрасываем дубли
	WHERE
		rn = 1 
	AND 
		donation_status IN ('Без справки', 'На модерации', 'Принята')
	GROUP BY user_id
)
, prepared_users AS (
	-- объединяем таблицы user_anon_data и user_donation
	SELECT
		uad.id
		, CASE
			-- C
			WHEN confirmed_donations = 0 THEN 'не_является_донором'
			ELSE 'является донором'
		END AS donor_status
		, CASE 
			WHEN count_bonuses_taken = 0 THEN 'без_бонусов'
			ELSE 'тратит_бонусы'
		END AS bonus_status
		, CASE
			--Сегментирууем id по возврасту
			WHEN uad.birth_date IS NULL THEN 'нет данных'
			WHEN dac.first_donation_date IS NULL THEN 'нет донаций'
			WHEN EXTRACT(YEAR FROM AGE(dac.first_donation_date, uad.birth_date)) < 18 THEN 'моложе_18'
			WHEN EXTRACT(YEAR FROM AGE(dac.first_donation_date, uad.birth_date)) < 30 THEN 'от_18_до_30'
			WHEN EXTRACT(YEAR FROM AGE(dac.first_donation_date, uad.birth_date)) < 40 THEN 'от_30_до_40'
			WHEN EXTRACT(YEAR FROM AGE(dac.first_donation_date, uad.birth_date)) < 50 THEN 'от_40_до_50'
			WHEN EXTRACT(YEAR FROM AGE(dac.first_donation_date, uad.birth_date)) < 60 THEN 'от_50_до_60'
			WHEN EXTRACT(YEAR FROM AGE(dac.first_donation_date, uad.birth_date)) < 65 THEN 'от_60_до_65'
			ELSE 'старше_65'
		END AS age_donor_categ
		-- заменяем пропуски
		, COALESCE(gender, 'нет_данных') AS gender
		, registration_date
		, birth_date
		, last_activity
		, COALESCE(blood_type, 'нет_данных') AS blood_type
		, COALESCE(honorary_donor, 'отсутствует') AS honorary_donor
		, icon_20
			OR icon_100 AS icon_status
			, email_is_specified
			OR phone_specified AS email_phone_donor
			, autho_vk
			OR autho_google AS networks_vk_google
			, confirmed_donations
			, count_bonuses_taken
		FROM
			donorsearch.user_anon_data uad
		LEFT JOIN donation_anon_clear dac 
		ON
			dac.user_id = uad.id
-- без региона,  почти не делают донаций. отсекаем пропуски.
		WHERE
			uad.region IS NOT NULL
) 
SELECT
	*
FROM
	prepared_users
-- фильтруем возрастные группы, которые 99% содержат ошибку
WHERE
	age_donor_categ NOT IN (
		'моложе_18', 'старше_65'
	)
--Готово

/*
ВЫВОДЫ:
1. Подготовлены отдельные датасеты для Python EDA:
   - события и донации по мероприятиям;
   - очищенная таблица донаций;
   - пользовательский профиль с базовыми сегментами.
 2. Из финального пользовательского датасета исключены записи:
   - без региона;
   - с возрастом младше 18 и старше 70 лет,
     так как такие значения вероятно являются ошибками данных.
   - статус донации: 'Без справки', 'На модерации', 'Принята'
 3. Подготовлены признаки для EDA:
   - donor_status;
   - bonus_status;
   - age_donor_category;
   - icon_status;
   - email_is_specified;
   - networks_vk_google.

*/