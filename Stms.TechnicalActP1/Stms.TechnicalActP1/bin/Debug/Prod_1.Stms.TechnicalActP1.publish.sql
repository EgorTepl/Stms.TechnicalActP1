﻿/*
Deployment script for AX_Prod_Interface

This code was generated by a tool.
Changes to this file may cause incorrect behavior and will be lost if
the code is regenerated.
*/

GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;

SET NUMERIC_ROUNDABORT OFF;


GO
:setvar DB_SOURCE_NAME "AX_Prod"
:setvar PROJECT_SCHEMA_NAME "dev"
:setvar UTC_OFFSET "3"
:setvar DatabaseName "AX_Prod_Interface"
:setvar DefaultFilePrefix "AX_Prod_Interface"
:setvar DefaultDataPath "D:\SQLBases\"
:setvar DefaultLogPath "D:\SQLBases\"

GO
:on error exit
GO
/*
Detect SQLCMD mode and disable script execution if SQLCMD mode is not supported.
To re-enable the script after enabling SQLCMD mode, execute the following:
SET NOEXEC OFF; 
*/
:setvar __IsSqlCmdEnabled "True"
GO
IF N'$(__IsSqlCmdEnabled)' NOT LIKE N'True'
    BEGIN
        PRINT N'SQLCMD mode must be enabled to successfully execute this script.';
        SET NOEXEC ON;
    END


GO
USE [$(DatabaseName)];


GO
/*
 Pre-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be executed before the build script.	
 Use SQLCMD syntax to include a file in the pre-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the pre-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'$(PROJECT_SCHEMA_NAME)')
	EXEC ('CREATE SCHEMA $(PROJECT_SCHEMA_NAME)')
GO

DROP VIEW IF EXISTS [$(PROJECT_SCHEMA_NAME)].[V_PBI_10988_TECHNICAL_ACT_P1]
GO

DROP VIEW IF EXISTS [$(PROJECT_SCHEMA_NAME)].[V_PBI_10988_TECHNICAL_ACT_P1_ACTUAL_DATE]
GO

DROP VIEW IF EXISTS [$(PROJECT_SCHEMA_NAME)].[V_PBI_10988_TECHNICAL_ACT_P1_ASUT_DATE]
GO

CREATE VIEW [$(PROJECT_SCHEMA_NAME)].[V_PBI_10988_TECHNICAL_ACT_P1]
AS
	SELECT 1 AS col
GO

CREATE VIEW [$(PROJECT_SCHEMA_NAME)].[V_PBI_10988_TECHNICAL_ACT_P1_ACTUAL_DATE]
AS
	SELECT 1 AS col
GO

CREATE VIEW [$(PROJECT_SCHEMA_NAME)].[V_PBI_10988_TECHNICAL_ACT_P1_ASUT_DATE]
AS
	SELECT 1 AS col
GO

GO


-- =============================================
-- Author: TeploukhovES 
-- Create date: 03.10.2022
-- Pbi: http://eka-devops/devops/Sinara/DAX/_workitems/edit/10988
-- Description: Сводный технический акт П-1 с пробегами по дате из систем АСУТ РЖД
-- Change 23.11.2021 http://eka-devops/devops/Sinara/DAX/_workitems/edit/11959
-- Change 10.01.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/11880
-- Change 02.10.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/12766
-- Change 03.10.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/13390
-- =============================================
ALTER VIEW [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P1_ASUT_DATE
AS

WITH customer_cte AS
( -- Определяем заказчика (для шапки отчета)
	SELECT DISTINCT
		m.NAME AS customerName,
		rd1.ORGANIZATIONID AS orgId
	 FROM [$(DB_SOURCE_NAME)]..SSMMANAGEMENTS AS m
	 INNER JOIN [$(DB_SOURCE_NAME)]..SSMREGISTRATIONDEPOT AS rd1
		ON m.MANAGEMENTID = rd1.MANAGEMENTID
), 
executor_cte AS
( -- Определяем исполнителя (для шапки отчета)
	SELECT DISTINCT
		hrmo.DESCRIPTION + N' ' + hrmo_par.DESCRIPTION AS executorName,
		hrmo_par.HRMORGANIZATIONID AS orgId
	 FROM [$(DB_SOURCE_NAME)]..RPAYHRMORGANIZATION AS hrmo
	 INNER JOIN [$(DB_SOURCE_NAME)]..RPAYHRMORGANIZATION AS hrmo_par -- Находим родителя
		 ON hrmo.HRMORGANIZATIONID = hrmo_par.PARENTORGANIZATIONID
),
serviceKind_cte AS
( -- отбираем ServiceKindID по полю SyntheticKindRecID при условии, что Synthetic = 1 и Main = 1 (синтетический вид СО)
	SELECT DISTINCT
		aj1.SERVICEKINDID AS aj_servicekindid,
		sk2.SERVICEKINDID AS sk_servicekindid
	 FROM [$(DB_SOURCE_NAME)]..SSMARRIVALJOURNAL AS aj1
	 INNER JOIN [$(DB_SOURCE_NAME)]..SSMSERVICEKINDS AS sk1
		 ON aj1.SERVICEKINDID = sk1.SERVICEKINDID AND sk1.SYNTHETIC = 1
	 INNER JOIN [$(DB_SOURCE_NAME)]..SSMSYNTHETICSERVICEKINDS AS ssk1
		 ON sk1.RECID = ssk1.SERVICEKINDRECID AND ssk1.MAIN = 1
	 INNER JOIN [$(DB_SOURCE_NAME)]..SSMSERVICEKINDS AS sk2
		 ON sk2.RECID = ssk1.SYNTHETICKINDRECID
),
depotName_cte AS
( -- убираем скобки у депо приписки
	SELECT
		srd.REGISTRATIONDEPOTID,
		SUBSTRING(srd.NAME, CHARINDEX('«' , srd.NAME) + 1,
			LEN(srd.NAME) - CHARINDEX('«' , srd.NAME) - 1) AS depotName
	FROM [$(DB_SOURCE_NAME)]..SSMREGISTRATIONDEPOT AS srd
),
arrivalJournal_cte AS
(
	SELECT
		saj.ARRIVALJOURNALID,
		saj.SERVICEKINDID,
		saj.RPAYHRMORGANIZATIONID,
		saj.OBJECTCLASSID,
		saj.REGISTRATIONSODATEASUT,
		saj.SUPPLEMENTNUM,
		IIF(YEAR(saj.REGISTRATIONSODATEASUT) = 1900,
			NULL, CONVERT(NVARCHAR, DATEADD(hour, CAST('$(UTC_OFFSET)' AS int) ,saj.REGISTRATIONSODATEASUT), 104)) AS REGISTRATIONSOASUT_DATE,
		IIF(YEAR(saj.REGISTRATIONSODATEASUT) = 1900,
			NULL, CONVERT(TIME(0), DATEADD(hour, CAST('$(UTC_OFFSET)' AS int), saj.REGISTRATIONSODATEASUT))) AS REGISTRATIONSOASUT_TIME,
		IIF(YEAR(saj.REPAIRSOENDDATEASUT) = 1900,
			NULL, CONVERT(NVARCHAR, DATEADD(hour, CAST('$(UTC_OFFSET)' AS int), saj.REPAIRSOENDDATEASUT), 104)) AS REPAIRSOENDASUT_DATE,
		IIF(YEAR(saj.REPAIRSOENDDATEASUT) = 1900,
			NULL, CONVERT(TIME(0), DATEADD(hour, CAST('$(UTC_OFFSET)' AS int), saj.REPAIRSOENDDATEASUT))) AS REPAIRSOENDASUT_TIME,
		IIF(YEAR(saj.REPAIRSOENDDATEASUT) = 1900 OR YEAR(saj.REGISTRATIONSODATEASUT) = 1900,
			NULL, CAST(DATEDIFF(second, saj.REGISTRATIONSODATEASUT, saj.REPAIRSOENDDATEASUT)
				/ 3600.0 AS decimal(9,2))) AS REPAIRTIME,
		DATEADD(hour, CAST('$(UTC_OFFSET)' AS int), saj.REPAIRSOENDDATEASUT) AS REPAIRSOENDDATEASUT
	FROM [$(DB_SOURCE_NAME)]..SSMARRIVALJOURNAL AS saj
	WHERE
		YEAR(saj.REPAIRSOENDDATEASUT) != 1900
		AND saj.STATUS <> 3
),
ssmMaintenanceRegistry_cte AS
(
	SELECT
		smr.OBJECTID,
		smr.STARTDATE,
		smr.SERVICEKINDID,
		smr.SYNTHETICSERVICEKINDID,
		CAST(CEILING(smr.DEVELOPMENTVALUETIME / 24) AS NVARCHAR) + N'с' AS DEVELOPMENTVALUETIME,
		CAST(CAST(smr.DEVELOPMENTVALUEDISTANCE AS INT) AS NVARCHAR) AS DEVELOPMENTVALUEDISTANCE
	FROM [$(DB_SOURCE_NAME)]..SSMMAINTENANCEREGISTRY as smr
)
SELECT DISTINCT
	aj.OBJECTCLASSID AS [Серия локомотива],
	o.FACTORYID AS [Номер Локомотива],
	1 AS [Кол-во секций],
	aj.REGISTRATIONSOASUT_DATE AS [Дата постановки локомотива в ремонт],
	aj.REGISTRATIONSOASUT_TIME AS [Время постановки локомотива в ремонт],
	aj.SUPPLEMENTNUM AS [№ Акта приемки Локомотива в ремонт],
	CASE
		WHEN sk.SYNTHETIC = 0 THEN aj.SERVICEKINDID
		WHEN sk.SYNTHETIC = 1 THEN serviceKind_cte.sk_servicekindid
		ELSE null
	END AS [Вид ремонта],
	aj.REPAIRSOENDASUT_DATE AS [Дата выхода локомотива из ремонта],
	aj.REPAIRSOENDASUT_TIME AS [Время выхода локомотива из ремонта],
	aj.SUPPLEMENTNUM AS [№ Акта приемки Локомотива из ремонта],
	aj.REPAIRTIME AS [Кол-во нахождения в ремонте одной секции],
	aj.REPAIRTIME AS [Кол-во нахождения всех секций в ремонте(суммарно)],
	rd.depotName AS [Депо приписки(Примечание)],
	CASE
		WHEN obja.ACTUALMOVEMENTKINDID IN (N'МАНВ', N'ХОЗ')
		THEN mr.DEVELOPMENTVALUETIME
		ELSE mr.DEVELOPMENTVALUEDISTANCE 
		END AS [Пробег на момент постановки локомотива на СО от последнего аналогичного ремонта],
	aj.ARRIVALJOURNALID AS [Код журнала прибытия],
	aj.RPAYHRMORGANIZATIONID AS [Фильтр подразделения],
	aj.REPAIRSOENDDATEASUT AS [Фильтр даты],
	customer_cte.customerName AS [Заказчик],
	executor_cte.executorName AS [Исполнитель],
	aj.REGISTRATIONSODATEASUT AS [Сортировка даты и времени]
FROM [$(DB_SOURCE_NAME)]..SSMARRIVALJOURNALLINE AS ajl -- Строки журнала прибытия
INNER JOIN arrivalJournal_cte AS aj -- Журнал прибытия
	ON (ajl.ARRIVALJOURNALID = aj.ARRIVALJOURNALID)
LEFT JOIN [$(DB_SOURCE_NAME)]..SSMOBJECTS AS o -- Объекты обслуживания
	ON ajl.OBJECTID = o.OBJECTID
LEFT JOIN [$(DB_SOURCE_NAME)]..SSMSERVICEKINDS AS sk -- Виды обслуживания
	ON aj.SERVICEKINDID = sk.SERVICEKINDID
LEFT JOIN serviceKind_cte -- Синтетические виды СО
	ON aj.SERVICEKINDID = serviceKind_cte.aj_servicekindid
LEFT JOIN depotName_cte AS rd -- Депо приписки
	ON ajl.REGISTRATIONDEPOTID = rd.REGISTRATIONDEPOTID
LEFT JOIN customer_cte -- Заказчик
	ON aj.RPAYHRMORGANIZATIONID = customer_cte.orgId
LEFT JOIN executor_cte -- Исполнитель
	ON aj.RPAYHRMORGANIZATIONID = executor_cte.orgId
LEFT JOIN ssmMaintenanceRegistry_cte AS mr -- Пробег
	ON (ajl.OBJECTID = mr.OBJECTID) AND (aj.REGISTRATIONSODATEASUT = mr.STARTDATE)
		AND (((serviceKind_cte.aj_servicekindid = mr.SYNTHETICSERVICEKINDID)
		AND (serviceKind_cte.sk_servicekindid = mr.SERVICEKINDID)) OR (aj.SERVICEKINDID = mr.SERVICEKINDID))
LEFT JOIN [$(DB_SOURCE_NAME)]..SSMOBJECTATTRIBUTES AS obja
	ON o.ATTRIBUTEID = obja.RECID
GO


-- =============================================
-- Author: TeploukhovES 
-- Create date: 03.10.2022
-- Pbi: http://eka-devops/devops/Sinara/DAX/_workitems/edit/10988
-- Description: Сводный технический акт П-1 с пробегами по фактической дате
-- Change 23.11.2021 http://eka-devops/devops/Sinara/DAX/_workitems/edit/11959
-- Change 10.01.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/11880
-- Change 02.10.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/12766
-- Change 03.10.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/13390
-- =============================================
ALTER VIEW [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P1_ACTUAL_DATE
AS

WITH customer_cte AS
( -- Определяем заказчика (для шапки отчета)
	SELECT DISTINCT
		m.NAME AS customerName,
		rd1.ORGANIZATIONID AS orgId
	 FROM [$(DB_SOURCE_NAME)]..SSMMANAGEMENTS AS m
	 INNER JOIN [$(DB_SOURCE_NAME)]..SSMREGISTRATIONDEPOT AS rd1
		ON m.MANAGEMENTID = rd1.MANAGEMENTID
), 
executor_cte AS
( -- Определяем исполнителя (для шапки отчета)
	SELECT DISTINCT
		hrmo.DESCRIPTION + ' ' + hrmo_par.DESCRIPTION AS executorName,
		hrmo_par.HRMORGANIZATIONID AS orgId
	 FROM [$(DB_SOURCE_NAME)]..RPAYHRMORGANIZATION AS hrmo
	 INNER JOIN [$(DB_SOURCE_NAME)]..RPAYHRMORGANIZATION AS hrmo_par -- Находим родителя
		 ON hrmo.HRMORGANIZATIONID = hrmo_par.PARENTORGANIZATIONID
),
serviceKind_cte AS
( -- отбираем ServiceKindID по полю SyntheticKindRecID при условии, что Synthetic = 1 и Main = 1 (синтетический вид СО)
	SELECT DISTINCT
		aj1.SERVICEKINDID AS aj_servicekindid,
		sk2.SERVICEKINDID AS sk_servicekindid
	 FROM [$(DB_SOURCE_NAME)]..SSMARRIVALJOURNAL AS aj1
	 INNER JOIN [$(DB_SOURCE_NAME)]..SSMSERVICEKINDS AS sk1
		 ON aj1.SERVICEKINDID = sk1.SERVICEKINDID AND sk1.SYNTHETIC = 1
	 INNER JOIN [$(DB_SOURCE_NAME)]..SSMSYNTHETICSERVICEKINDS AS ssk1
		 ON sk1.RECID = ssk1.SERVICEKINDRECID AND ssk1.MAIN = 1
	 INNER JOIN [$(DB_SOURCE_NAME)]..SSMSERVICEKINDS AS sk2
		 ON sk2.RECID = ssk1.SYNTHETICKINDRECID
),
depotName_cte AS
( -- убираем скобки у депо приписки
	SELECT
		srd.REGISTRATIONDEPOTID,
		SUBSTRING(srd.NAME, CHARINDEX('«' , srd.NAME) + 1,
			LEN(srd.NAME) - CHARINDEX('«' , srd.NAME) - 1) AS depotName
	FROM [$(DB_SOURCE_NAME)]..SSMREGISTRATIONDEPOT AS srd
),
arrivalJournal_cte AS
(
	SELECT
		saj.ARRIVALJOURNALID,
		saj.SERVICEKINDID,
		saj.RPAYHRMORGANIZATIONID,
		saj.OBJECTCLASSID,
		saj.REGISTRATIONSODATEASUT,
		saj.SUPPLEMENTNUM,
		IIF(YEAR(saj.REGISTRATIONSODATEASUT) = 1900,
			NULL, CONVERT(NVARCHAR, DATEADD(hour, CAST('$(UTC_OFFSET)' AS int) ,saj.REGISTRATIONSODATEASUT), 104)) AS REGISTRATIONSOASUT_DATE,
		IIF(YEAR(saj.REGISTRATIONSODATEASUT) = 1900,
			NULL, CONVERT(TIME(0), DATEADD(hour, CAST('$(UTC_OFFSET)' AS int), saj.REGISTRATIONSODATEASUT))) AS REGISTRATIONSOASUT_TIME,
		IIF(YEAR(saj.REPAIRSOENDDATEASUT) = 1900,
			NULL, CONVERT(NVARCHAR, DATEADD(hour, CAST('$(UTC_OFFSET)' AS int), saj.REPAIRSOENDDATEASUT), 104)) AS REPAIRSOENDASUT_DATE,
		IIF(YEAR(saj.REPAIRSOENDDATEASUT) = 1900,
			NULL, CONVERT(TIME(0), DATEADD(hour, CAST('$(UTC_OFFSET)' AS int), saj.REPAIRSOENDDATEASUT))) AS REPAIRSOENDASUT_TIME,
		IIF(YEAR(saj.REPAIRSOENDDATEASUT) = 1900 OR YEAR(saj.REGISTRATIONSODATEASUT) = 1900,
			NULL, CAST(DATEDIFF(second, saj.REGISTRATIONSODATEASUT, saj.REPAIRSOENDDATEASUT)
				/ 3600.0 AS decimal(9,2))) AS REPAIRTIME,
		IIF(YEAR(saj.REPAIRSOENDDATE) = 1900,
			NULL, DATEADD(hour, CAST('$(UTC_OFFSET)' AS int), saj.REPAIRSOENDDATE)) AS REPAIRSOENDDATE
	FROM [$(DB_SOURCE_NAME)]..SSMARRIVALJOURNAL AS saj
	WHERE
		YEAR(saj.REPAIRSOENDDATEASUT) = 1900
		AND saj.STATUS <> 3
),
ssmMaintenanceRegistry_cte AS
(
	SELECT
		smr.OBJECTID,
		smr.STARTDATE,
		smr.SERVICEKINDID,
		smr.SYNTHETICSERVICEKINDID,
		CAST(CEILING(smr.DEVELOPMENTVALUETIME / 24) AS NVARCHAR) + N'с' AS DEVELOPMENTVALUETIME,
		CAST(CAST(smr.DEVELOPMENTVALUEDISTANCE AS INT) AS NVARCHAR) AS DEVELOPMENTVALUEDISTANCE
	FROM [$(DB_SOURCE_NAME)]..SSMMAINTENANCEREGISTRY as smr
)
SELECT DISTINCT
	aj.OBJECTCLASSID AS [Серия локомотива],
	o.FACTORYID AS [Номер Локомотива],
	1 AS [Кол-во секций],
	aj.REGISTRATIONSOASUT_DATE AS [Дата постановки локомотива в ремонт],
	aj.REGISTRATIONSOASUT_TIME AS [Время постановки локомотива в ремонт],
	aj.SUPPLEMENTNUM AS [№ Акта приемки Локомотива в ремонт],
	CASE
		WHEN sk.SYNTHETIC = 0 THEN aj.SERVICEKINDID
		WHEN sk.SYNTHETIC = 1 THEN serviceKind_cte.sk_servicekindid
		ELSE null
	END AS [Вид ремонта],
	aj.REPAIRSOENDASUT_DATE AS [Дата выхода локомотива из ремонта],
	aj.REPAIRSOENDASUT_TIME AS [Время выхода локомотива из ремонта],
	aj.SUPPLEMENTNUM AS [№ Акта приемки Локомотива из ремонта],
	aj.REPAIRTIME AS [Кол-во нахождения в ремонте одной секции],
	aj.REPAIRTIME AS [Кол-во нахождения всех секций в ремонте(суммарно)],
	rd.depotName AS [Депо приписки(Примечание)],
	CASE
		WHEN obja.ACTUALMOVEMENTKINDID IN (N'МАНВ', N'ХОЗ')
		THEN mr.DEVELOPMENTVALUETIME
		ELSE mr.DEVELOPMENTVALUEDISTANCE 
		END AS [Пробег на момент постановки локомотива на СО от последнего аналогичного ремонта],
	aj.ARRIVALJOURNALID AS [Код журнала прибытия],
	aj.RPAYHRMORGANIZATIONID AS [Фильтр подразделения],
	aj.REPAIRSOENDDATE AS [Фильтр даты],
	customer_cte.customerName AS [Заказчик],
	executor_cte.executorName AS [Исполнитель],
	aj.REGISTRATIONSODATEASUT AS [Сортировка даты и времени]
FROM [$(DB_SOURCE_NAME)]..SSMARRIVALJOURNALLINE AS ajl -- Строки журнала прибытия
INNER JOIN arrivalJournal_cte AS aj -- Журнал прибытия
	ON (ajl.ARRIVALJOURNALID = aj.ARRIVALJOURNALID)
LEFT JOIN [$(DB_SOURCE_NAME)]..SSMOBJECTS AS o -- Объекты обслуживания
	ON ajl.OBJECTID = o.OBJECTID
LEFT JOIN [$(DB_SOURCE_NAME)]..SSMSERVICEKINDS AS sk -- Виды обслуживания
	ON aj.SERVICEKINDID = sk.SERVICEKINDID
LEFT JOIN serviceKind_cte -- Синтетические виды СО
	ON aj.SERVICEKINDID = serviceKind_cte.aj_servicekindid
LEFT JOIN depotName_cte AS rd -- Депо приписки
	ON ajl.REGISTRATIONDEPOTID = rd.REGISTRATIONDEPOTID
LEFT JOIN customer_cte -- Заказчик
	ON aj.RPAYHRMORGANIZATIONID = customer_cte.orgId
LEFT JOIN executor_cte -- Исполнитель
	ON aj.RPAYHRMORGANIZATIONID = executor_cte.orgId
LEFT JOIN ssmMaintenanceRegistry_cte AS mr -- Пробег
	ON (ajl.OBJECTID = mr.OBJECTID) AND (aj.REGISTRATIONSODATEASUT = mr.STARTDATE)
		AND (((serviceKind_cte.aj_servicekindid = mr.SYNTHETICSERVICEKINDID)
		AND (serviceKind_cte.sk_servicekindid = mr.SERVICEKINDID)) OR (aj.SERVICEKINDID = mr.SERVICEKINDID))
LEFT JOIN [$(DB_SOURCE_NAME)]..SSMOBJECTATTRIBUTES AS obja
	ON o.ATTRIBUTEID = obja.RECID
GO


-- =============================================
-- Author: TeploukhovES 
-- Create date: 20.08.2021
-- Pbi: http://eka-devops/devops/Sinara/DAX/_workitems/edit/10988
-- Description: Сводный технический акт П-1 с пробегами
-- Change 23.11.2021 http://eka-devops/devops/Sinara/DAX/_workitems/edit/11959
-- Change 10.01.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/11880
-- Change 02.10.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/12766
-- Change 03.10.2022 http://eka-devops/devops/Sinara/DAX/_workitems/edit/13390
-- =============================================
ALTER VIEW [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P1
AS
	SELECT
		techActAsut.[Серия локомотива],
		techActAsut.[Номер Локомотива],
		techActAsut.[Кол-во секций],
		techActAsut.[Дата постановки локомотива в ремонт],
		techActAsut.[Время постановки локомотива в ремонт],
		techActAsut.[№ Акта приемки Локомотива в ремонт],
		techActAsut.[Вид ремонта],
		techActAsut.[Дата выхода локомотива из ремонта],
		techActAsut.[Время выхода локомотива из ремонта],
		techActAsut.[№ Акта приемки Локомотива из ремонта],
		techActAsut.[Кол-во нахождения в ремонте одной секции],
		techActAsut.[Кол-во нахождения всех секций в ремонте(суммарно)],
		techActAsut.[Депо приписки(Примечание)],
		techActAsut.[Пробег на момент постановки локомотива на СО от последнего аналогичного ремонта],
		techActAsut.[Код журнала прибытия],
		techActAsut.[Фильтр подразделения],
		techActAsut.[Фильтр даты],
		techActAsut.[Заказчик],
		techActAsut.[Исполнитель],
		techActAsut.[Сортировка даты и времени]
	FROM [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P1_ASUT_DATE AS techActAsut

	UNION ALL

	SELECT
		techActActual.[Серия локомотива],
		techActActual.[Номер Локомотива],
		techActActual.[Кол-во секций],
		techActActual.[Дата постановки локомотива в ремонт],
		techActActual.[Время постановки локомотива в ремонт],
		techActActual.[№ Акта приемки Локомотива в ремонт],
		techActActual.[Вид ремонта],
		techActActual.[Дата выхода локомотива из ремонта],
		techActActual.[Время выхода локомотива из ремонта],
		techActActual.[№ Акта приемки Локомотива из ремонта],
		techActActual.[Кол-во нахождения в ремонте одной секции],
		techActActual.[Кол-во нахождения всех секций в ремонте(суммарно)],
		techActActual.[Депо приписки(Примечание)],
		techActActual.[Пробег на момент постановки локомотива на СО от последнего аналогичного ремонта],
		techActActual.[Код журнала прибытия],
		techActActual.[Фильтр подразделения],
		techActActual.[Фильтр даты],
		techActActual.[Заказчик],
		techActActual.[Исполнитель],
		techActActual.[Сортировка даты и времени]
	FROM [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P1_ACTUAL_DATE AS techActActual
GO

GO
PRINT N'Update complete.';


GO
