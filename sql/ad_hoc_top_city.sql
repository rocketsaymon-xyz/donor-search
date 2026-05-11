/*

-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK: Regional donor activity analysis
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:
1. Определить города (ТОП 7) с наиболее высокой концентрацией пользователей, 
и оценить интенсивность повторных донаций.
	
Бизнес-смысл:
Находим города где уже есть активные доноры с регулярными донациями, в этих регионах можно проще развивать успех.
Опыт (реклама, продвижение) успешных городов в дальнейшем можно перенести в области где нужен рост. 
Коэффициент активности доноров позволит нам оценивать города, не только по количеству доноров или донаций, а по
условиям, эффективностью бонусных программ, работе с базами доноров.

Ограничения:
Исходные данные на портале изменить нельзя.
Очистка выполняется только SQL-запросами.
*/

WITH double_user_donation AS (
	-- убираем дубликаты из user_donation
	SELECT
		donor_id
		, event_id
		, donation_data
		, donation_count
		, ROW_NUMBER() OVER (
			--Нумеруем строки по дубликатам по столбцам
               PARTITION BY donor_id
			, event_id
			, donation_data
			, donation_count
		ORDER BY
			id
		) AS rn
	FROM
		donorsearch.user_donation
)
, clean_user_donation AS (
	SELECT
		donor_id
		, COUNT(event_id) AS cnt_event
		, MIN(donation_data) AS first_donation_date
		-- возраст считаем по дате регистрации (чтобы отсеять ошибочные возраста)
		, SUM(donation_count) AS sum_event_donation
	FROM
		double_user_donation
	WHERE
		rn = 1
		-- фильтруем. оставляем только оригинальные строки
	GROUP BY
		donor_id
)
, all_date AS (
	-- объединяем таблицы user_anon_data и user_donation
	SELECT
		uad.id
		, COALESCE(uad.region, 'нет_данных') AS region
		, uad.confirmed_donations
		, CASE
			--Сегментируем доноров по возврасту
			WHEN uad.birth_date IS NULL THEN 'нет данных'
			WHEN cud.first_donation_date IS NULL THEN 'нет донаций'
			WHEN EXTRACT(YEAR FROM AGE(cud.first_donation_date, uad.birth_date)) < 18 THEN 'моложе_18'
			WHEN EXTRACT(YEAR FROM AGE(cud.first_donation_date, uad.birth_date)) < 30 THEN 'от_18_до_30'
			WHEN EXTRACT(YEAR FROM AGE(cud.first_donation_date, uad.birth_date)) < 40 THEN 'от_30_до_40'
			WHEN EXTRACT(YEAR FROM AGE(cud.first_donation_date, uad.birth_date)) < 50 THEN 'от_40_до_50'
			WHEN EXTRACT(YEAR FROM AGE(cud.first_donation_date, uad.birth_date)) < 60 THEN 'от_50_до_60'
			WHEN EXTRACT(YEAR FROM AGE(cud.first_donation_date, uad.birth_date)) < 70 THEN 'от_60_до_70'
			ELSE 'старше_70'
		END AS age_donor_categ
	FROM
		donorsearch.user_anon_data uad
	LEFT JOIN clean_user_donation cud
        	ON
		cud.donor_id = uad.id
)
SELECT
	region
	-- количество всех польхователей в городе
	, COUNT(id) AS count_user
	-- количество доноров с донациями больше 0
	, COUNT(id) FILTER(WHERE confirmed_donations > 0) AS count_donor
	-- общее число донаций в городе
	, SUM(confirmed_donations) AS confirmed_donations
	-- смотрим активность доноров
	, ROUND(SUM(confirmed_donations)::NUMERIC / 
		NULLIF(COUNT(id) FILTER(WHERE confirmed_donations > 0), 0), 2) AS donation_frequency
FROM
	all_date
WHERE
	age_donor_categ NOT IN (
		'моложе_18', 'старше_70'
	)
	-- фильтруем возрастные группы, которые 99% содержат ошибку
GROUP BY
	region
ORDER BY
	count_user DESC
LIMIT 8 -- Изменил на 8, так как 1 строка без региона, а задача найти ТОП 7

/*
ВЫВОДЫ:
1. Пользователи без указанного региона практически не совершают донации.
   Вероятно, такие записи содержат неполные или низкокачественные данные.
   Рекомендуется исключать их из аналитических витрин/staging слоя.;
2. В крупных города на одного города приходися от 1 до 2 подтвержденных донаций;
3. Москва - лидерует по количеству доноров, однако не является лидером по donation_frequency.
   Это показывает, что высокий масштаб базы не всегда означает
   высокую регулярность донаций;
3. Казань, имеет лучшую активность среди ТОП городов (donation_frequency). 2,4 донации на одного донора.
	Это может свидетельствовать на хорошую работу по удержанию доноров;
4. Украина, Киев имеет худшую активность (donation_frequency), 100 доноров всего 25 донаций.

Рекомендации:
1. Изменить процесс регистрации, провести A/B тесты:
	* Обновить окно регистрации на сайте;
	* Добавить краткое  информационное сообщение о миссии донарства;
	* Предложить выбрать тип  будущей компенсации в момент регистрации, чтобы повысить желание пройти дальше;
2. Изучить рекламные и социальные активности в Москве и других ТОП 7 городах, провести аналогичные мероприятия в
	остатающих регионах.
3. Сделать дашборд и отслеживать количество коэффиент: количество донаций на одного донора.
*/
