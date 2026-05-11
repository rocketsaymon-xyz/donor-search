/*

-- =====================================================
-- PROJECT: DonorSearch Analytics
-- TASK:  Data Quality Check - events
-- AUTHOR: Saymon_XYZ
-- =====================================================

Цель:
Проверить таблицу donorsearch.events на:
1. структуру данных;
2. пропуски;
3. технические дубликаты;
4. Проверить типы данных;
5. Проверить на выбросы.

Бизнес-смысл:
Перед расчётом результатовности проведенных евентов нужно убедиться,
что таблица не завышает данные из-за дублей, столбца содержат актуальные значения без выбросов.

Ограничения:
Исходные данные на портале изменить нельзя.
Очистка выполняется только SQL-запросами.
*/

-- 1.  Изучаем данные
SELECT
	*
FROM donorsearch.events e 
LIMIT 10;

-- Смотрим столбец reg_count 
SELECT
	SUM(reg_count)
FROM donorsearch.events e;

-- 2. Считаем пропуски
SELECT
	COUNT(*) AS all_line -- количество строк 1536
	, COUNT(id) AS id_count
	, ROUND(100.0 * (COUNT(*) - COUNT(id)) / COUNT(*), 2) AS id_null_pct
	, COUNT(e.organization_id ) AS organization_id
	, ROUND(100.0 * (COUNT(*) - COUNT(organization_id)) / COUNT(*), 2) AS organization_id_null_pct
	, COUNT(e.event_begin ) AS event_begin
	, ROUND(100.0 * (COUNT(*) - COUNT(event_begin)) / COUNT(*), 2) AS event_begin_null_pct
	, COUNT(e.event_end ) AS event_end
	, ROUND(100.0 * (COUNT(*) - COUNT(event_end)) / COUNT(*), 2) AS event_end_null_pct
	, COUNT(e.reg_count ) AS reg_count
	, ROUND(100.0 * (COUNT(*) - COUNT(reg_count)) / COUNT(*), 2) AS reg_count_null_pct
	, COUNT(city) AS city
	, ROUND(100.0 * (COUNT(*) - COUNT(city)) / COUNT(*), 2) AS city_null_pct
FROM donorsearch.events e ;
-- Пропусков нет, есть только один пропуск в столбце city

-- 3.Изучаем дубликаты
WITH double_line AS (
SELECT
	*
	, COUNT(*) OVER(
	PARTITION BY organization_id, event_begin, event_end,  reg_count, city 
	) AS cnt_double
FROM donorsearch.events e 
)
SELECT
	*
FROM double_line 
WHERE cnt_double > 1;
-- Дубликаты есть.

--Считаем дубликаты
WITH double_line AS (
SELECT 
	*
	, ROW_NUMBER() OVER (
	PARTITION BY organization_id, event_begin, event_end,  reg_count, city 
	ORDER BY organization_id) AS cnt_double
FROM donorsearch.events e
)
SELECT 
	COUNT(*)
	, COUNT(*) FILTER (WHERE cnt_double > 1)
FROM double_line ;
-- дубликатов 15. удаляем.

-- 4. Проверяем типы данных
SELECT
	column_name
	, data_type
FROM information_schema.columns
WHERE table_schema = 'donorsearch'
	AND table_name = 'events';
-- типы данных соответствуют содержанию
	
-- 5. Ищем выбросы
SELECT
	MIN(event_begin) AS min_event_begin
	, MAX(event_begin) AS max_event_begin
	, MIN(event_end) AS min_event_end
	, MAX(event_end) AS max_event_end
	, MIN(reg_count) AS min_reg_count
	, MAX(reg_count) AS max_reg_count
	, AVG(reg_count) AS avg_reg_count
	,PERCENTILE_CONT(0.5)
    	WITHIN GROUP (ORDER BY reg_count) AS median_reg_count
FROM donorsearch.events;
-- event_begin, event_end соответствует датам работы проекта donorsearch
-- reg_count, соответствует адеватным значениям. но можно отметить, что средняя и медиана сильно меньше 
-- максимального количества участников. Можно сделать вывод, : распределение reg_count скошено.

*
ВЫВОДЫ:
1. Данные изучены. grain - 1 строка=1 мероприятие: его даты начала и конца, количество участников, город;
2. Пропусков нет, есть только один пропуск в столбце city;
3. Явные технические дубликаты обнаружены -15 строк (менее 1% данных), исключаем в staging;
4. Типы данных соответствуют содержанию;
5. Проверка на выбросы, виден перекос максмальных значений относительно средней и медианы, необходимо изучить: 
	какая доля мероприятий имело провальные результаты (менее 10 человек), 
	чем выделяются евенты с участниками свыше 10 человек (выбрать кол-во, которое обеспечивает 80% всего результата по донорам).
*/