Автор: Saymon\_XYZ
дата: 01.10.2025
проект: Donor Search

\--Задачи, AD hoc:\*
-- 1) ТОП города по донациям;
-- 2) По сегментации (гендер/возраст/бонус) определить топ 7 групп с самой большой долей донацией от общего числа;
-- 3) first\_time\_churn\_rate\_place. АнтиТОП 10 станций, где самая высокая доля доноров, которые сделали одну донацию и больше не вернулись;
-- 4) LTV за 2018 год (когорты по месяцам, год до пандемии и СВО). Как часто делаются донации;
-- 5) Определить месяца, с самой низкой и высокой активностью доноров (топ 2);
-- 6) Вычислить возможный фрод по получению бонусов. Доноров, которые больше получают подарков, чем сдают кровь;

\-- 7) Сегментация доноров по: гендерам/городам/возрасту (исключить до 18 и старше 70)/бонус за донат. Подготовка данных для EDA в Python;

\--	\* Код получился объемным, так как данные содержат пропуски и дубли. в каждом ad\_hoc запросе, производилась подготовка данных, так как не было возможности сохранить в исходный датасет ;

\--	и даже наоборот была практика по очистке и подготовке данных.





\--Задачи, AD hoc:
-- 1) ТОП города по донациям;



WITH double\_user\_donation AS ( -- убираем дубликаты из user\_donation

SELECT

&#x09;donor\_id

&#x09;, event\_id

&#x09;, donation\_data

&#x09;, donation\_count

&#x09;, ROW\_NUMBER() OVER (  --Нумеруем строки по дубликатам по столбцам

&#x20;              PARTITION BY donor\_id, event\_id, donation\_data, donation\_count

&#x20;              ORDER BY id

&#x20;          ) AS rn 

FROM

&#x09;donorsearch.user\_donation 

)

, clean\_user\_donation AS ( -- таблица для JOIN

&#x09;SELECT

&#x20;       donor\_id

&#x20;       , COUNT(event\_id) AS cnt\_event

&#x20;       , MIN(donation\_data) AS first\_donation\_date -- возраст считаем по дате регистрации (чтобы отсеять ошибочные возраста)

&#x20;       , SUM(donation\_count) AS sum\_event\_donationег

&#x20;   FROM double\_user\_donation

&#x20;   WHERE rn = 1  -- фильтруем. оставляем только оригинальные строки

&#x20;   GROUP BY donor\_id

)

, all\_date AS ( -- объединяем таблицы user\_anon\_data и user\_donation

&#x09;SELECT

&#x09;	uad.id

&#x09;	, COALESCE(uad.region, 'нет\_данных') AS region

&#x09;	, uad.confirmed\_donations

&#x09;	, CASE  --Сегментирууем доноров по возврасту

&#x09;		WHEN uad.birth\_date IS NULL THEN 'нет данных'

&#x09;		WHEN cud.first\_donation\_date IS NULL THEN 'нет донаций'

&#x09;		WHEN EXTRACT(YEAR FROM AGE(cud.first\_donation\_date, uad.birth\_date)) < 18 THEN 'моложе\_18'

&#x09;		WHEN EXTRACT(YEAR FROM AGE(cud.first\_donation\_date, uad.birth\_date)) < 30 THEN 'от\_18\_до\_30'

&#x09;		WHEN EXTRACT(YEAR FROM AGE(cud.first\_donation\_date, uad.birth\_date)) < 40 THEN 'от\_30\_до\_40'

&#x09;		WHEN EXTRACT(YEAR FROM AGE(cud.first\_donation\_date, uad.birth\_date)) < 50 THEN 'от\_40\_до\_50'

&#x09;		WHEN EXTRACT(YEAR FROM AGE(cud.first\_donation\_date, uad.birth\_date)) < 60 THEN 'от\_50\_до\_60'

&#x09;		WHEN EXTRACT(YEAR FROM AGE(cud.first\_donation\_date, uad.birth\_date)) < 70 THEN 'от\_60\_до\_70'

&#x09;		ELSE 'старше\_70'

&#x09;	END AS age\_donor\_categ

&#x09;FROM donorsearch.user\_anon\_data uad

&#x20;   	LEFT JOIN clean\_user\_donation cud

&#x20;       	ON cud.donor\_id = uad.id

)

SELECT

&#x09;region

&#x09;, COUNT(id) AS count\_donor  -- количество доноров в регионе

&#x09;, SUM(confirmed\_donations) AS confirmed\_donations -- общее число донаций в регионе

&#x09;, ROUND(SUM(confirmed\_donations)::NUMERIC / COUNT(id), 2) AS ratio\_donor  -- смотрим активность доноров

FROM all\_date

WHERE age\_donor\_categ NOT IN ('моложе\_18', 'старше\_70') -- фильтруем возрастные группы, которые 99% содержат ошибку

GROUP BY region 

ORDER BY count\_donor DESC

LIMIT 7;



|region|count\_donor|confirmed\_donations|ratio\_donor|
|-|-|-|-|
|нет\_данных|100571|112|0.00|
|Россия, Москва|37818|39634|1.05|
|Россия, Санкт-Петербург|13137|15329|1.17|
|Россия, Татарстан, Казань|6606|15874|2.40|
|Украина, Киевская область, Киев|3541|876|0.25|
|Россия, Новосибирская область, Новосибирск|3310|3155|0.95|
|Россия, Свердловская область, Екатеринбург|3082|4747|1.54|



\-- Выводы:

\-- 100 тысяч доноров, которые не указывают город и самое главное почти не делают донаций (на 1000 доноров всего 1 донация);

\-- Важно! изучить по имеющимся данным, что объединяет людей, которые не проходят полную регистрацию. Доноров, которые не прошли регистрацию стоит исключить из исследования донаций;

\-- На одного донора приходят от 1 до 2 донаций в больших городах;

\-- Москва - Номер один по количеству доноров;

\-- Казань, имеет лучшую активность среди ТОП городов (ratio\_donor). 2,4 донации на одного донора;

\-- Украина, Киев имеет худшую активность (ratio\_donor), 100 доноров всего 25 донаций.



\-- Рекомендации:
-- Удалить из анализа доноров, которые не указывает адрес для донации;

&#x09;-- Предположу, что люди не прошли полный этап регистрации и не стали донорами;

&#x09;-- Возможные причины: отсутствует поликлиники в городе, проблема с сайтом, регистрация слишком сложная, либо есть ограничения по здоровью;

\-- Сделать воронку донаций (аналог продаж), провести A/B и выявить возможные причины: 

&#x09;-- 1) Обновить окно регистрации на сайте;

&#x09;-- 2) Добавить краткое  информационное сообщение о миссии донарства;

&#x09;-- 3) Предложить выбрать тип  будущей компенсации в момент регистрации, чтобы повысить желание пройти дальше;

\-- Посчитать среднюю активность по городам. Выявить города с низким коэффициентом и провести опрос среди доноров: "что им мешает, помогать людям?";

\-- Сравнить низкую активность по городам с высоким Churn поликлиник. Дать Обратную связь в больницы/ Поменять точки донации;

\-- Запустить челендж: битвы городов за первое место по донорству, чтобы увеличить количество доноров.



\-- 2) По сегментации (гендер/возраст/бонус) определить топ 7 групп:

&#x09;-- с самой большой долей донаций от общего числа;

&#x09;-- сколько группа получает бонусов на 100 донаций;

&#x09;-- Процент донаций в евентах от общего числа донаций в группе.



WITH user\_donation\_double\_line AS( --CTE запрос на поиск дубликатов user\_donation

&#x09;SELECT 

&#x09;	donor\_id

&#x09;	, event\_id

&#x09;	, donation\_count

&#x09;	, ROW\_NUMBER() OVER( -- нумером строки по дубликатам

&#x09;	PARTITION BY donor\_id, event\_id, donation\_data, donation\_count

&#x09;	ORDER BY donor\_id) AS rn\_double

&#x09;FROM donorsearch.user\_donation ud

)

, user\_donation\_clear AS ( -- таблица EVENT для JOIN

&#x09;SELECT

&#x09;	donor\_id

&#x09;	, SUM(donation\_count) sum\_event\_donate

&#x09;	, COUNT(event\_id) AS cnt\_event -- сколько event\_id принял участие

&#x09;FROM user\_donation\_double\_line

&#x09;WHERE rn\_double = 1 -- убираем дубликаты

&#x09;GROUP BY donor\_id)

, donation\_anon\_double\_line AS ( -- убираем дубликаты из donation\_anon

&#x09;SELECT

&#x09;	user\_id

&#x09;	, donation\_date

&#x09;	, donation\_status

&#x09;	, ROW\_NUMBER() OVER (  --Нумеруем строки по дубликатам по столбцам

&#x20;              PARTITION BY user\_id, blood\_class, donation\_date, plan\_date, confirmation, donation\_status, donation\_added\_date

&#x20;              ORDER BY id

&#x20;          ) AS rn 

&#x09;FROM donorsearch.donation\_anon 

&#x09;WHERE donation\_status IN ('Без справки', 'На модерации', 'Принята')

)

, donation\_anon\_clear AS ( -- таблица donation\_anon для JOIN

&#x20;   SELECT

&#x20;       user\_id

&#x20;       , COUNT(\*) AS all\_donate

&#x20;       , MIN(donation\_date) AS first\_donation\_date -- возраст считаем по дате регистрации (чтобы отсеять ошибочные возраста)		

&#x20;   FROM donation\_anon\_double\_line

&#x20;   WHERE rn = 1  -- фильтруем. оставляем только оригинальные строки

&#x20;   	AND donation\_status IN ('На модерации', 'Принята')

&#x20;   GROUP BY user\_id

)

, segment AS (  -- СТЕ объединяем user\_anon\_data, donation\_anon и event\_donation, сегментация по возрасту.

&#x09;SELECT

&#x09;	uad.id

&#x09;	, COALESCE(gender, 'нет\_данных') AS gender -- убираем пропуски

&#x09;	, COALESCE(region, 'нет\_данных') AS region

&#x09;	, uad.confirmed\_donations

&#x09;	, count\_bonuses\_taken 

&#x09;	, CASE 

&#x09;		WHEN dac.first\_donation\_date IS NULL THEN 'нет\_донаций'

&#x09;		WHEN uad.birth\_date IS NULL THEN 'нет\_данных'

&#x09;		WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 18 THEN 'моложе\_18'

&#x09;		WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 30 THEN 'от\_18\_до\_30'

&#x20;       	WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 40 THEN 'от\_30\_до\_40'

&#x20;       	WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 50 THEN 'от\_40\_до\_50'

&#x20;       	WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 60 THEN 'от\_50\_до\_60'

&#x20;       	WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 70 THEN 'от\_60\_до\_70'

&#x20;       	ELSE 'старше\_70'

&#x09;	END AS age\_donor\_categ

&#x09;	, CASE 

&#x09;		WHEN count\_bonuses\_taken = 0 THEN 'без\_бонусов'

&#x09;		ELSE 'тратит\_бонусы'

&#x09;	END AS bonus\_status

&#x09;	, cnt\_event AS cnt\_event

&#x09;	, sum\_event\_donate AS sum\_event\_donate

&#x09;	, all\_donate AS all\_donate

&#x09;FROM donorsearch.user\_anon\_data uad 

&#x09;LEFT JOIN user\_donation\_clear udc

&#x09;	ON uad.id = udc.donor\_id

&#x09;LEFT JOIN donation\_anon\_clear dac

&#x09;	ON uad.id = dac.user\_id

&#x09;WHERE uad.region IS NOT NULL

)

, top\_5\_gender AS ( -- СТЕ оставляем группы с 50 донорами и более. ТОП 5 по проценту донаций

SELECT

&#x09;gender

&#x09;, age\_donor\_categ  -- сегменты по группам

&#x09;, bonus\_status -- использование бонусов

&#x09;, ROUND(SUM(confirmed\_donations)::NUMERIC / 

&#x09;	SUM(SUM(confirmed\_donations)) OVER()\*100, 2) AS percent\_donation  -- процент донаций от общего числа

&#x09;, ROUND(SUM(count\_bonuses\_taken)::numeric / SUM(confirmed\_donations)\* 100, 2) AS percent\_bonus\_100\_donations

&#x09;, ROUND(SUM(sum\_event\_donate)::numeric / SUM(confirmed\_donations) \*100, 2) AS percent\_event\_donations

FROM segment

GROUP BY gender, age\_donor\_categ, bonus\_status

HAVING COUNT(id) > 50

ORDER BY percent\_donation DESC NULLS LAST 

LIMIT 5   --Берем ТОП 7 групп

)

SELECT 

&#x09;\*

FROM top\_5\_gender

UNION ALL 

SELECT

&#x20;   'All\_gender' AS gender

&#x20;   , 'All\_age' AS age\_donor\_cat

&#x20;   , 'All\_bonuse\_ase' AS bonus\_status

&#x20;   , SUM(percent\_donation) AS percent\_donation

&#x20;   , SUM(percent\_bonus\_100\_donations) AS percent\_bonus\_100\_donations

&#x20;   , SUM(percent\_event\_donations) AS percent\_event\_donations

FROM top\_5\_gender;



|gender|age\_donor\_categ|bonus\_status|percent\_donation|percent\_bonus\_100\_donations|percent\_event\_donations|
|-|-|-|-|-|-|
|нет\_данных|нет\_данных|без\_бонусов|18.27|0.00|0.35|
|Мужской|от\_18\_до\_30|тратит\_бонусы|16.21|15.76|9.74|
|Мужской|от\_18\_до\_30|без\_бонусов|14.14|0.00|2.61|
|Женский|от\_18\_до\_30|без\_бонусов|9.24|0.00|2.11|
|Женский|от\_18\_до\_30|тратит\_бонусы|7.30|20.73|9.66|
|All\_gender|All\_age|All\_bonuse\_ase|65.16|36.49|24.47|



\--Выводы:

\-- Важно! здесь нарушен принцип: один отчет одна идея. Но, первичный анализ с глубоким разбиением дает направление для движения;

\-- 18,27% или почти каждая пятая донация идет от доноров, которые не указывают свои данные (возраст, гендер итп);

\-- Самые активные доноры люди от 18 до 30 лет (мужчины и женщины), которые пользуются бонусами и не пользуются. Остальные все возрастные категории имеют все 35% донаций;

\-- Донаций от мужчин почти в двое больше, чем от женщин в ТОП группах (30% против 16% от общего значения);

\-- Высокая доля донаций.



\-- Рекомендации:

\-- подготовить с шпаргалку (инструкцию) для донора, где будет прописана важность полной регистрации;

\-- Для самой активной аудитории сделать акцию: приведи Папу/Маму. Активные доноры могут повлиять на пассивное население. Этим самым можем увеличить количество доноров и донаций;

\-- Провести аудит рекламы/способы общения с аудиторией. Выбрать площадки для продвижения аудитории 40+. Это способ привлечь новую аудиторию;

\-- провести аудит event мероприятий, в чем их отличие успешных и провальных. Скорректировать будущие рекламные кампании;

\-- Сделать обращение к женской аудитории, что они только регистрируются, но не делают донаций. Попросить их о помощи;

\-- Провести дополнительный анализ по полученным бонусам. на 100 донаций приходится только 15-20 бонусов среди тех кто бонусы получают. Сколько доноров, которые делают только для бонусов (95%);

\-- Ввести дополнительную категорию: регулярный донор, от одноразового. их отношение к бонусам и социальной активности.


-- 3) first\_time\_churn\_rate\_place. АнтиТОП 10 станций, где самая высокая доля доноров, которые сделали одну донацию и больше не вернулись в программу.



WITH donation\_anon\_double\_line AS(

SELECT 

&#x09;user\_id

&#x09;, donation\_date

&#x09;, donation\_type

&#x09;, donation\_place

&#x09;, city

&#x09;, donation\_status

&#x09;, ROW\_NUMBER() OVER( --нумеруем дубликаты

&#x09;PARTITION BY user\_id, donation\_date, donation\_type, donation\_place, donation\_status

&#x09;ORDER BY id) AS cnt\_double

FROM donorsearch.donation\_anon da

WHERE (donation\_date BETWEEN '1975-01-01' AND '2023-11-28') --фильтр по существующим датам

&#x09;AND (donation\_status IN ('Без справки', 'На модерации', 'Принята')) -- фильтр по статусам, оставляем только подтвержденные донации

) 

, donation\_anon\_clear AS (

SELECT 

&#x09;city

&#x09;, donation\_place

&#x09;, user\_id

&#x09;, donation\_type

&#x09;, donation\_status

&#x09;, donation\_date

&#x09;, COUNT(donation\_date) OVER( -- считаем количество донаций на одного пользователя

&#x09;PARTITION BY user\_id) AS number\_donation

&#x09;, ROW\_NUMBER() OVER (  -- при условии, что не может быть две донации в один день.

&#x09;PARTITION BY user\_id ORDER BY donation\_date) AS number\_donation\_date

FROM donation\_anon\_double\_line

WHERE cnt\_double = 1

)

, first\_churn\_rate AS (

SELECT 

&#x09;city

&#x09;, donation\_place

&#x09;, ROUND(COUNT(user\_id) FILTER (WHERE number\_donation = 1)::numeric

&#x20;   	/ COUNT(user\_id) \* 100,

&#x20;   	2) AS first\_time\_churn\_rate

FROM donation\_anon\_clear

WHERE number\_donation\_date = 1 AND donation\_place NOT IN ('Выездная акция')

GROUP BY city, donation\_place

HAVING  COUNT(user\_id) > 50

)

, anti\_top\_10\_churn\_rate AS(

SELECT

&#x09;\*

FROM first\_churn\_rate

ORDER BY first\_time\_churn\_rate DESC

LIMIT 10)

SELECT

&#x09;\*

FROM anti\_top\_10\_churn\_rate

UNION ALL

SELECT

&#x20;   'ALL' AS city

&#x20;   , 'MEDIAN' AS donation\_place

&#x20;   , ROUND(

&#x20;       (percentile\_cont(0.5) 

&#x20;    WITHIN GROUP (ORDER BY first\_time\_churn\_rate))::numeric,

&#x20;   2)AS first\_time\_churn\_rate

FROM first\_churn\_rate;



|city|donation\_place|first\_time\_churn\_rate|
|-|-|-|
|Якутск|Станция переливания крови Республики Саха (Якутия)|73.47|
|Ярославль|Отделение забора крови №2 Ярославской СПК (Клиническая больница СМП им. Н.В. Соловьева)|72.22|
|Щёлково|ГБУЗ МО "Щёлковская станция переливания крови"|70.91|
|Астана|Городской центр крови|69.70|
|Иваново|Филиал "Ивановский 1" Ивановской областной станции переливания крови|68.75|
|Москва|ОПК ГКБ им. В.М. Буянова ДЗМ, отделение переливания крови|68.48|
|Ишим|Областная станция переливания крови, Ишимский филиал|68.42|
|Киев|Киевский городской центр крови|66.67|
|Кинешма|Кинешемский филиал Ивановской областной станции переливания крови|66.67|
|Липецк|ГУЗ "Липецкая областная станция переливания крови"|66.24|
|ALL|MEDIAN|52.56|





\--Вывод:

\-- Важно!. Фильтр  donation\_place NOT IN ('Выездная акция'). Донор не может самостоятельно принять решение вернуться еще раз. По ним необходимо делать отдельный анализ;

\-- Медиана по churn\_rate среди станций донации 52,56%. каждый второй донор пришел только один раз сдать кровь;

\-- Есть станции анти лидеры. В Якутске, Ярославля, Щёлково. 7 человек из 10 больше не возвращаются в программу;

\-- В отчете станции по переливанию, которые посетили от 50 доноров.



\-- Рекомендации:

\-- В EDA анализе выбрать срок для CHURN rate, что будет считаться уходом;

\-- Половина доноров отваливается после первой донации. Провести A/B тесты с новыми донорами, отследить изменения:

&#x09;-- добавить им благодарственные письма (другую не материальную мотивацию);

&#x09;-- После определение сроков CHURN потери клиентов, настроить выборку user\_id  для повторного приглашения после первой рекомендации;

\-- Провести опрос среди доноров по этим станциям ("что необходимо изменить):

&#x09;-- дать обратную связь станциям. запросить план изменений;

&#x09;-- если провести изменения не получается в течении 3 месяцев, изменить станцию донации.



\-- 4) LTV за 2018 год. Окно 12 месяцев, когорты по месяцам (год до пандемии и СВО). Количество доноров и среднее количество донаций за 12 мес.;



WITH donation\_anon\_double\_line AS ( -- нумеруем дубликаты

SELECT 

&#x09;\*

&#x09;, ROW\_NUMBER() OVER(-- нумеруем дубликаты

&#x09;PARTITION BY user\_id, blood\_class, donation\_date, plan\_date, donation\_type, city, donation\_status, donation\_added\_date

&#x09;ORDER BY id) AS cnt\_double

FROM donorsearch.donation\_anon da

WHERE (donation\_date BETWEEN '1975-01-01' AND '2020-12-31')  -- фильтруем сразу дату

&#x09;AND (donation\_status IN ('Без справки', 'На модерации', 'Принята'))-- фильтр по существующим датам)

)

, donation\_anon\_clear AS (

SELECT

&#x09;region

&#x09;, user\_id 

&#x09;, donation\_date

&#x09;, MIN(donation\_date)  -- мин дата для определения когорты.

&#x09;	OVER(PARTITION BY user\_id) AS cohort\_date 

&#x09;, DATE\_TRUNC('month', MIN(donation\_date) 

&#x09;	OVER (PARTITION BY user\_id))::date  AS cohort\_month

FROM donation\_anon\_double\_line

WHERE cnt\_double = 1 -- оставляем 

)

, ltv\_12m AS (

SELECT 

&#x09;user\_id

&#x09;, cohort\_month

&#x09;, COUNT(DISTINCT user\_id) AS users\_cnt

&#x09;, COUNT(\*) AS user\_ltv\_12m

FROM donation\_anon\_clear 

WHERE cohort\_month >= '2018-01-01'AND 

&#x09;cohort\_month < '2019-01-01' AND

&#x09;donation\_date < cohort\_date + INTERVAL '365 days' 

GROUP BY user\_id, cohort\_month

)

SELECT

&#x09;cohort\_month

&#x09;, SUM(users\_cnt) AS users\_cohort

&#x09;, ROUND(AVG(user\_ltv\_12m), 2) AS ltv\_users

FROM ltv\_12m

GROUP BY cohort\_month

ORDER BY cohort\_month;



|cohort\_month|users\_cohort|ltv\_users|
|-|-|-|
|2018-01-01|122|3.02|
|2018-02-01|150|2.59|
|2018-03-01|188|2.40|
|2018-04-01|275|2.40|
|2018-05-01|243|2.26|
|2018-06-01|253|2.13|
|2018-07-01|350|2.17|
|2018-08-01|272|2.39|
|2018-09-01|247|1.96|
|2018-10-01|337|2.05|
|2018-11-01|297|2.08|
|2018-12-01|237|2.07|



\-- Выводы:

\-- Летние когорты (июль–авг) чуть лучше после просадки;

\-- Сильная сезонность/каналы привлечения влияют;

\-- Размер когорты растёт, но качество падает → рост “в ширину”;

\-- Мужчинам рекомендуется сдавать кровь до 5, а женщинам до 4 раз в год. Показатели можно улучшить минимум на 150%.


-- 5) donor\_ad\_hoc\_monthly\_active\_donors\_(mad).Определить месяца, с самой низкой и высокой активностью доноров (топ 2), за 2018-2020 годы;

\-- Фильтр. убрать выездные акции. так как они нарушают статистику по самовольному желанию донора.



WITH donation\_anon\_double\_line AS ( -- нумерация строк по дублям4

&#x09;SELECT 

&#x09;	user\_id

&#x09;	, da.donation\_date 

&#x09;	, da.donation\_type

&#x09;	, ROW\_NUMBER() OVER(

&#x09;	PARTITION BY user\_id, blood\_class, donation\_date, plan\_date, donation\_type, region, donation\_added\_date

&#x09;	ORDER BY id) AS cnt\_double

&#x09;FROM donorsearch.donation\_anon da

&#x09;WHERE donation\_status IN  ('Без справки', 'Принята', 'На модерации') AND -- убираем донации, которые не приняли

&#x09;	donation\_date >= DATE '2018-01-01'  -- фильтр донаций за 3 года с 2018 до 2020 включительно.

&#x09;		AND donation\_date < DATE '2020-12-31'

)

, donation\_anon\_clear AS (

&#x09;SELECT

&#x09;	user\_id

&#x09;	, donation\_date

&#x09;	, donation\_type

&#x09;	, TO\_CHAR(donation\_date, 'Month') AS month\_donate  -- название месяца

&#x09;FROM donation\_anon\_double\_line

&#x09;WHERE cnt\_double = 1

&#x09;)

SELECT 

&#x09;month\_donate

&#x09;, COUNT(user\_id) AS count\_donate -- общее количество донаций.

&#x09;, ROUND(COUNT(user\_id) FILTER (WHERE donation\_type = 'Платно')::NUMERIC

&#x09;	/ COUNT(user\_id) \*100, 2) AS percent\_bonus\_donat  -- доля платных донаций от общего числа.

&#x09;, NTILE(3) OVER (ORDER BY COUNT(user\_id) DESC) AS activity\_month -- категории активности доноров 1 самый большой.

FROM donation\_anon\_clear

GROUP BY month\_donate

ORDER BY count\_donate DESC;



|month\_donate|count\_donate|percent\_bonus\_donat|activity\_month|
|-|-|-|-|
|April|4575|6.75|1|
|July|4273|6.62|1|
|October|4246|6.29|1|
|December|4212|6.13|1|
|June|4198|6.26|2|
|March|4125|6.98|2|
|August|4008|5.84|2|
|May|3978|6.69|2|
|November|3796|7.24|3|
|February|3745|6.49|3|
|September|3616|6.69|3|
|January|3526|6.15|3|





\-- Выводы:

\-- В группе 3 (самая низкая активность) 2 месяца осенних и  2 месяца зимних;

\-- в весенние и летние месяца всегда по 4000 с плюсом донаций. Это первая и вторая группа;

\-- Между бонусными донациями и активностью доноров по месяцам видимой корреляции нет.



\-- Рекомендации:

\-- В зимние и осенние месяца необходимы активности по евентам и бонусным программам для привлечения клиентов;

\-- Постоянным донорам обозначить проблемные периоды и попросить их изменить даты сдачи крови.




-- 6) Вычислить возможный фрод по получению бонусов. Доноров, которые больше получают подарков, чем сдают кровь;



SELECT

&#x09;DISTINCT(user\_id) -- оставляем уникальные user\_id (user\_bonus\_count, donation\_count) дублированы в строках

&#x09;, uab.user\_bonus\_count 

&#x09;, uab.donation\_count 

&#x09;, uab.user\_bonus\_count::numeric / NULLIF(uab.donation\_count, 0)\*100 AS part\_bonus\_donation -- коэффициент получение бонусов к донациям

FROM donorsearch.user\_anon\_bonus uab

ORDER BY part\_bonus\_donation DESC NULLS LAST

LIMIT 15; -- оставлеям ТОП 15 user\_id



|user\_id|user\_bonus\_count|donation\_count|part\_bonus\_donation|
|-|-|-|-|
|213470|19|1|1900.00|
|195696|31|2|1550.00|
|196761|30|2|1500.00|
|203693|14|1|1400.00|
|216709|14|1|1400.00|
|154191|12|1|1200.00|
|196372|24|2|1200.00|
|196035|12|1|1200.00|
|226888|10|1|1000.00|
|215838|10|1|1000.00|
|212688|10|1|1000.00|
|153188|9|1|900.000|
|200221|51|6|850.00|
|198396|17|2|850.00|
|196583|8|1|800.00|



\--Выводы:

\-- Есть user\_id, которые получают бонусов и подарков больше, чем делают донаций;

\-- необходимо вводить систему безопасности для сохранности бонусов.



\-- Рекомендации:

\-- Посчитать сколько user\_id пользуются системой;

\-- Проанализировать портрет фрод\_доноров: регион, возраст, когда делают донации, какие подарки получают;

\-- Сообщить организаторам:

&#x09;-- ограничить определенных доноров;

&#x09;-- разработать систему защиты.



\-- 7) Сегментация доноров по: гендерам/городам/возрасту (исключить до 18 и старше 70)/бонус за донат. Подготовка данных для EDA в Python;

\-- Датасет donor\_ad\_hoc\_eda\_donation\_anon. Из таблиц donation\_anon;

\-- Датасет donor\_ad\_hoc\_eda\_user\_anon\_data. Из таблиц user\_anon\_data (с возрастом, с учетом от первой донацией);

\-- Датасет donor\_ad\_hoc\_eda\_events\_donation. Из таблиц events и user\_donation.



\--Находим последнюю выгрузку user\_donation, events;



WITH user\_donation\_double\_line AS ( -- нумеруем дубли

&#x09;SELECT \* 

&#x09;	, ROW\_NUMBER() OVER(

&#x09;		PARTITION BY donor\_id, event\_id, donation\_data, donation\_count

&#x09;		) AS cnt\_double

&#x09;FROM donorsearch.user\_donation ud 

) 

, user\_donation\_clear AS (

&#x09;SELECT 

&#x09;	donor\_id

&#x09;	, event\_id

&#x09;	, donation\_data

&#x09;	, donation\_count

&#x09;FROM user\_donation\_double\_line

&#x09;WHERE cnt\_double = 1

)

, events\_double\_line AS(

&#x09;SELECT \*

&#x09;	, ROW\_NUMBER() OVER(

&#x09;		PARTITION BY organization\_id, event\_begin, event\_end,  reg\_count, city 

&#x09;		) AS cnt\_double

&#x09;FROM donorsearch.events e 

), events\_clear AS (

&#x09;SELECT

&#x09;	id

&#x09;	, event\_begin

&#x09;	, event\_end

&#x09;	, reg\_count

&#x09;	, city

&#x09;FROM events\_double\_line

&#x09;WHERE cnt\_double = 1

)

SELECT 

&#x09;donor\_id

&#x09;, udc.event\_id

&#x09;, event\_begin

&#x09;, event\_end

&#x09;, city

&#x09;, reg\_count AS events\_all\_donor

&#x09;, donation\_data

&#x09;, donation\_count

FROM user\_donation\_clear udc

LEFT JOIN events\_clear ec ON 

&#x09;udc.event\_id = ec.id

ORDER BY donor\_id;

\-- Готов Датасет donor\_ad\_hoc\_eda\_events\_donation



\--Подготовка данных donation\_anon



WITH donation\_anon\_double\_line AS ( -- убираем дубликаты из user\_donation

&#x09;SELECT

&#x09;	user\_id

&#x09;	, blood\_class

&#x09;	, donation\_date

&#x09;	, donation\_type

&#x09;	, donation\_status

&#x09;	, donation\_place

&#x09;	, MIN(donation\_date) OVER(PARTITION BY user\_id 

&#x09;		ORDER BY donation\_date) AS first\_donation\_date -- возраст считаем по дате регистрации (чтобы отсеять ошибочные возраста)

&#x09;	, ROW\_NUMBER() OVER (  --Нумеруем строки по дубликатам по столбцам

&#x20;              PARTITION BY user\_id, blood\_class, donation\_date, donation\_type, donation\_status, donation\_place

&#x20;              ORDER BY id

&#x20;          ) AS rn 

&#x09;FROM donorsearch.donation\_anon 

)

, donation\_anon\_clear AS (

&#x09;SELECT  --

&#x09;	user\_id

&#x09;	, blood\_class

&#x09;	, donation\_date

&#x09;	, donation\_type

&#x09;	, donation\_status

&#x09;	, donation\_place

&#x09;	, first\_donation\_date

&#x09;FROM donation\_anon\_double\_line

&#x09;WHERE rn = 1 --оставляем только первый ранг. сбрасываем дубли

)

SELECT \*

FROM donation\_anon\_clear

WHERE donation\_status IN ('Принята', 'На модерации', 'Без справки');



\-- Готов donor\_ad\_hoc\_eda\_user\_anon\_data.





\-- Подготовка данных user\_anon\_data;



WITH donation\_anon\_double\_line AS ( -- убираем дубликаты из user\_donation

&#x09;SELECT

&#x09;	user\_id

&#x09;	, donation\_status

&#x09;	, MIN(donation\_date) OVER(PARTITION BY user\_id 

&#x09;		ORDER BY donation\_date) AS first\_donation\_date -- возраст считаем по дате регистрации (чтобы отсеять ошибочные возраста)

&#x09;	, ROW\_NUMBER() OVER (  --Нумеруем строки по дубликатам по столбцам

&#x20;              PARTITION BY user\_id, blood\_class, donation\_date, donation\_type, donation\_status, donation\_place

&#x20;              ORDER BY id

&#x20;          ) AS rn 

&#x09;FROM donorsearch.donation\_anon 

)

, donation\_anon\_clear AS (

&#x09;SELECT  --

&#x09;	user\_id

&#x09;	, donation\_status

&#x09;	, first\_donation\_date

&#x09;FROM donation\_anon\_double\_line

&#x09;WHERE rn = 1 --оставляем только первый ранг. сбрасываем дубли

), all\_date AS ( -- объединяем таблицы user\_anon\_data и user\_donation

&#x09;SELECT

&#x09;	uad.id

&#x09;	, CASE   -- C

&#x09;		WHEN confirmed\_donations = 0 THEN 'не\_является\_донором'

&#x09;		ELSE 'является донором'

&#x09;	END AS donor\_yes\_no

&#x09;	, CASE 

&#x09;		WHEN count\_bonuses\_taken = 0 THEN 'без\_бонусов'

&#x09;		ELSE 'тратит\_бонусы'

&#x09;	END AS bonus\_status

&#x09;	, CASE  --Сегментирууем id по возврасту

&#x09;		WHEN uad.birth\_date IS NULL THEN 'нет данных'

&#x09;		WHEN dac.first\_donation\_date IS NULL THEN 'нет донаций'

&#x20;     		WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 18 THEN 'моложе\_18'

&#x20;       	WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 30 THEN 'от\_18\_до\_30'

&#x20;       	WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 40 THEN 'от\_30\_до\_40'

&#x20;       	WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 50 THEN 'от\_40\_до\_50'

&#x20;       	WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 60 THEN 'от\_50\_до\_60'

&#x20;       	WHEN EXTRACT(YEAR FROM AGE(dac.first\_donation\_date, uad.birth\_date)) < 70 THEN 'от\_60\_до\_70'

&#x20;       	ELSE 'старше\_70'

&#x09;	END AS age\_donor\_categ

&#x09;	, COALESCE(gender, 'нет\_данных') AS gender -- заменяем пропуски

&#x09;	, registration\_date

&#x09;	, birth\_date

&#x09;	, last\_activity

&#x09;	, COALESCE(blood\_type, 'нет\_данных') AS blood\_type

&#x09;	, COALESCE(honorary\_donor, 'отсутствует') AS honorary\_donor

&#x09;	, icon\_20 OR icon\_100 AS icon\_status

&#x09;	, email\_is\_specified OR phone\_specified AS email\_phone\_donor

&#x09;	, autho\_vk  OR autho\_google AS networks\_vk\_google

&#x09;	, confirmed\_donations

&#x09;	, count\_bonuses\_taken 

&#x09;FROM donorsearch.user\_anon\_data uad

&#x09;LEFT JOIN donation\_anon\_clear dac 

&#x09;	ON dac.user\_id = uad.id

&#x09;WHERE uad.region IS NOT NULL  -- без региона,  почти не делают донаций. отсекаем пропуски.)

) 

SELECT

&#x09;\*

FROM all\_date

WHERE age\_donor\_categ NOT IN ('моложе\_18', 'старше\_70'); -- фильтруем возрастные группы, которые 99% содержат ошибку



\-- Готов staging слой. donor\_ad\_hoc\_eda\_donation\_anon;

\-- Выводы будут EDA анализа.





