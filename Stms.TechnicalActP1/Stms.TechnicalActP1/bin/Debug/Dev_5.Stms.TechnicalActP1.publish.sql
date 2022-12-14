/*
Deployment script for AX_Test_Interface

This code was generated by a tool.
Changes to this file may cause incorrect behavior and will be lost if
the code is regenerated.
*/

GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;

SET NUMERIC_ROUNDABORT OFF;


GO
:setvar DB_SOURCE_NAME "AX_Test"
:setvar DB_TARGET_NAME "AX_Test_Interface"
:setvar PROJECT_SCHEMA_NAME "dev"
:setvar UTC_OFFSET "3"
:setvar DatabaseName "AX_Test_Interface"
:setvar DefaultFilePrefix "AX_Test_Interface"
:setvar DefaultDataPath "E:\MSSQL\Data\"
:setvar DefaultLogPath "E:\MSSQL\Data\"

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

DROP VIEW IF EXISTS [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P1
GO

CREATE VIEW [$(PROJECT_SCHEMA_NAME)].[V_PBI_10988_TECHNICAL_ACT_P1]
AS
	SELECT 1 AS col
GO

GO

-- =============================================
-- Author: Teploukhov ES 
-- Create date: 20.08.2021
-- Pbi: http://eka-devops/devops/Sinara/DAX/_workitems/edit/10988
-- Description: Сводный технический акт П-1 с пробегами
-- 23.11.2021 доработка http://eka-devops/devops/Sinara/DAX/_workitems/edit/11959
-- 10.01.2022 доработка http://eka-devops/devops/Sinara/DAX/_workitems/edit/11880
-- 02.10.2022 доработка http://eka-devops/devops/Sinara/DAX/_workitems/edit/12766
-- =============================================
ALTER VIEW [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P1
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
		saj.REGISTRATIONSODATE,
		saj.SUPPLEMENTNUM,
		CONVERT (NVARCHAR, DATEADD(hh, CAST('$(UTC_OFFSET)' AS int), saj.REGISTRATIONSODATE),104) AS REGISTRATIONSO_DATE,
		CONVERT(TIME(0), DATEADD(hh, CAST('$(UTC_OFFSET)' AS int), saj.REGISTRATIONSODATE)) AS REGISTRATIONSO_TIME,
		IIF(YEAR(saj.REPAIRSOENDDATE) = 1900
			, NULL, CONVERT (NVARCHAR, 
				DATEADD(hh, CAST('$(UTC_OFFSET)' AS int), saj.REPAIRSOENDDATE),104)) AS REPAIRSOEND_DATE,
		IIF(YEAR(saj.REPAIRSOENDDATE) = 1900
			, NULL, CONVERT(TIME(0), 
				DATEADD(hh, CAST('$(UTC_OFFSET)' AS int), saj.REPAIRSOENDDATE))) AS REPAIRSOEND_TIME,
		IIF(YEAR(saj.REPAIRSOENDDATE) = 1900
			, NULL, CAST(DATEDIFF(ss, saj.REGISTRATIONSODATE, saj.REPAIRSOENDDATE )
				/ 3600.0 AS DECIMAL(16,2))) AS REPAIRTIME,
		IIF(YEAR(saj.REPAIRSOENDDATE) = 1900,
			NULL, DATEADD(hh, CAST('$(UTC_OFFSET)' AS int), saj.REPAIRSOENDDATE)) AS REPAIRSOENDDATE,
		DATEADD(hh, CAST('$(UTC_OFFSET)' AS int), saj.REGISTRATIONSODATE) AS REGISTRATIONSODATE_sort
	FROM [$(DB_SOURCE_NAME)]..SSMARRIVALJOURNAL AS saj 
	WHERE saj.STATUS <> 3
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
	aj.REGISTRATIONSO_DATE AS [Дата постановки локомотива в ремонт],
	aj.REGISTRATIONSO_TIME AS [Время постановки локомотива в ремонт],
	aj.SUPPLEMENTNUM AS [№ Акта приемки Локомотива в ремонт],
	CASE
		WHEN sk.SYNTHETIC = 0 THEN aj.SERVICEKINDID
		WHEN sk.SYNTHETIC = 1 THEN serviceKind_cte.sk_servicekindid
		ELSE null
	END AS [Вид ремонта],
	aj.REPAIRSOEND_DATE AS [Дата выхода локомотива из ремонта],
	aj.REPAIRSOEND_TIME AS [Время выхода локомотива из ремонта],
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
	aj.REGISTRATIONSODATE AS [Сортировка даты и времени]
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
LEFT JOIN ssmMaintenanceRegistry_cte AS mr
	ON (ajl.OBJECTID = mr.OBJECTID) AND (aj.REGISTRATIONSODATE = mr.STARTDATE)
		AND (((serviceKind_cte.aj_servicekindid = mr.SYNTHETICSERVICEKINDID)
		AND (serviceKind_cte.sk_servicekindid = mr.SERVICEKINDID)) OR (aj.SERVICEKINDID = mr.SERVICEKINDID))
LEFT JOIN [$(DB_SOURCE_NAME)]..SSMOBJECTATTRIBUTES AS obja
	ON o.ATTRIBUTEID = obja.RECID
GO

GO
PRINT N'Update complete.';


GO
