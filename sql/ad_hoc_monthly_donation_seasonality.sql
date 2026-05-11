/*

-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK: Monthly donation seasonality analysis
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:
1. Определить месяца с самыми наибольшим и наименьшим количеством донаций.
Анализируем сезонный паттерн по месяцам, агрегируя 2019–2020 годы.
Период: 2 года. 
	
Бизнес-смысл:
Контроль донаций крови поможет сбалансировать достаточность в больницах. На основе данных можно сместить проводимые ивенты
или рекламное продвижение на месяца с низкой активностью. Это может снизить риск дефицита крови и повысить стабильность supply.

Ограничения:
Исходные данные на портале изменить нельзя.
Очистка выполняется только SQL-запросами.
*/


WITH donation_anon_double_line AS (
	-- нумерация строк по дублями
	SELECT 
		user_id
		, da.donation_date
		, da.donation_type
		, ROW_NUMBER() OVER(
		PARTITION BY user_id, blood_class, donation_date, plan_date, donation_type, region, donation_added_date
		ORDER BY id) AS cnt_double
	FROM
		donorsearch.donation_anon da
	WHERE
		-- убираем донации, которые не приняли
		donation_status IN (
			'Без справки', 'Принята', 'На модерации'
		)
	-- Фильтр донаций за 2019–2020 годы включительно
		AND donation_date >= DATE '2019-01-01'
		AND donation_date < DATE '2021-01-01'
)
, donation_anon_clear AS (
	SELECT
		user_id
		, donation_date
		, donation_type
		, TO_CHAR(donation_date, 'Month') AS month_donate
		-- название месяца
	FROM
		donation_anon_double_line
	WHERE
		cnt_double = 1
)
SELECT 
	month_donate
	-- grain 1 строка = 1 донация
	, COUNT(*) AS count_donate
	-- общее количество донаций.
	, ROUND(COUNT(*) FILTER (WHERE donation_type = 'Платно')::NUMERIC
		/ COUNT(*) * 100, 2) AS paid_donation_share_pct
	-- доля платных донаций от общего числа.
	, NTILE(3) OVER (
	ORDER BY
		COUNT(*) DESC
	) AS activity_month
	-- категории активности доноров 1 самый большой.
FROM
	donation_anon_clear
GROUP BY
	month_donate
ORDER BY
	count_donate DESC;

/*
-- Выводы:
--  В данных наблюдается сезонность донорской активности:
   2 осенних и 1 зимний месяцев попадает в группу низкой активности;
-- Весенние и летние месяцы демонстрируют более высокий объем донаций,
   что может указывать на сезонные различия в поведении доноров;
-- Видимой связи между долей платных донаций и общим количеством донаций на этом уровне агрегации не обнаружено.
   Для проверки нужна корреляция или анализ на уровне user_id / city / month.

-- Рекомендации:
-- В месяца с низкой активностью запускать рекламные компании и ивенты для увеличение количества донаций;
-- Постоянным донорам сообщить проблемные месяца и попросить их изменить даты сдачи крови.
-- Дополнительно проверить сезонность по городам. Так как общий паттерн может скрывать региональные различия.

*/