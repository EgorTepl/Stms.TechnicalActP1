﻿/*
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

DROP VIEW IF EXISTS [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P11
GO

-- =============================================
-- Author: Teploukhov ES 
-- Create date: 20.08.2021
-- PBI: http://eka-devops/devops/Sinara/DAX/_workitems/edit/10988
-- Description: Сводный технический акт П-1 с пробегами
-- 23.11.2021 доработка http://eka-devops/devops/Sinara/DAX/_workitems/edit/11959
-- 10.01.2022 доработка http://eka-devops/devops/Sinara/DAX/_workitems/edit/11880
-- =============================================
CREATE VIEW [$(PROJECT_SCHEMA_NAME)].[V_PBI_10988_TECHNICAL_ACT_P11]
AS
	SELECT 1 AS col
GO

GO
/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
ALTER VIEW [$(PROJECT_SCHEMA_NAME)].V_PBI_10988_TECHNICAL_ACT_P11
AS

with cte1 as ( -- Определяем заказчика (для шапки отчета)
	select distinct
		m.NAME as Customer
		, rd1.ORGANIZATIONID as OrgID
	 from [$(DB_SOURCE_NAME)]..SSMMANAGEMENTS m
	 inner join [$(DB_SOURCE_NAME)]..SSMREGISTRATIONDEPOT rd1
	 on m.MANAGEMENTID = rd1.MANAGEMENTID
		), 
		cte2 as ( -- Определяем исполнителя (для шапки отчета)
			select 
				hrmo.DESCRIPTION + ' ' + hrmo_par.DESCRIPTION as Executor
				, hrmo_par.HRMORGANIZATIONID as OrgID
			 from [$(DB_SOURCE_NAME)]..RPAYHRMORGANIZATION hrmo
			 inner join [$(DB_SOURCE_NAME)]..RPAYHRMORGANIZATION hrmo_par -- Находим родителя
			 on hrmo.HRMORGANIZATIONID = hrmo_par.PARENTORGANIZATIONID
		),
		cte3 as ( -- отбираем ServiceKindID по полю SyntheticKindRecID при условии, что Synthetic = 1 и Main = 1 (синтетический вид СО)
			select
				aj1.SERVICEKINDID as aj_servicekindid
				, sk2.SERVICEKINDID as sk_servicekindid
			 from [$(DB_SOURCE_NAME)]..SSMARRIVALJOURNAL aj1
			 inner join [$(DB_SOURCE_NAME)]..SSMSERVICEKINDS sk1
			 on aj1.SERVICEKINDID = sk1.SERVICEKINDID and sk1.SYNTHETIC = 1
			 inner join [$(DB_SOURCE_NAME)]..SSMSYNTHETICSERVICEKINDS ssk1 -- Синтетические виды СО
			 on sk1.RECID = ssk1.SERVICEKINDRECID and ssk1.MAIN = 1
			 inner join [$(DB_SOURCE_NAME)]..SSMSERVICEKINDS sk2
			 on sk2.RECID = ssk1.SYNTHETICKINDRECID
		),
		cte4 as ( -- Основной запрос
	 		select distinct
				 aj.OBJECTCLASSID																		as [Серия локомотива]
				, o.FACTORYID																			as [Номер Локомотива]
				, 1																						as [Кол-во секций]
				/*, ''																					as [Фактический пробег(часы в эксплуатации) всех секций локомотива без превышения межремонтного преиода км/час]
				, ''																					as [Фактический пробег(часы в эксплуатации) всех секций локомотива с превышением межремонтного преиода км/час]
				, ''																					as [Фактический пробег(часы в эксплуатации) всех секций локомотива с превышением межремонтного преиода допущенный по]
				, ''																					as [Фактический пробег(часы в эксплуатации) всех секций подлежащий оплате км/час]*/
				, convert (nvarchar, dateadd(hh,CAST('$(UTC_OFFSET)' AS int), aj.REGISTRATIONSODATE),104)				as [Дата постановки локомотива в ремонт] -- изменил формат даты 'dd.MM.yyyy' 20210818
				, convert(time(0), dateadd(hh,CAST('$(UTC_OFFSET)' AS int), aj.REGISTRATIONSODATE))					as [Время постановки локомотива в ремонт]
				, aj.SUPPLEMENTNUM																		as [№ Акта приемки Локомотива в ремонт]
				, case
					when sk.SYNTHETIC = 0 then aj.SERVICEKINDID
					when sk.SYNTHETIC = 1 then cte3.sk_servicekindid
					else null
					end																					as [Вид ремонта]
				, iif(aj.REPAIRSOENDDATE like '%1900%'
					, null, convert (nvarchar, dateadd(hh,CAST('$(UTC_OFFSET)' AS int), aj.REPAIRSOENDDATE),104))		as [Дата выхода локомотива из ремонта] -- изменил формат даты 'dd.MM.yyyy' 20210818
				, iif(aj.REPAIRSOENDDATE like '%1900%'
					, null, convert(time(0), dateadd(hh,CAST('$(UTC_OFFSET)' AS int), aj.REPAIRSOENDDATE)))			as [Время выхода локомотива из ремонта]
				, aj.SUPPLEMENTNUM																		as [№ Акта приемки Локомотива из ремонта]
				, iif(aj.REPAIRSOENDDATE like '%1900%'
					, null, cast(datediff(ss, aj.REGISTRATIONSODATE ,aj.REPAIRSOENDDATE )
						/ 3600.0 as decimal(10,2)))														as [Кол-во нахождения в ремонте одной секции]
				, iif(aj.REPAIRSOENDDATE like '%1900%'
					, null, cast(datediff(ss, aj.REGISTRATIONSODATE ,aj.REPAIRSOENDDATE )
						/ 3600.0 as decimal(10,2)))														as [Кол-во нахождения всех секций в ремонте(суммарно)]
				, rd.NAME																				as [Депо приписки(Примечание)]
				--, ''																					as [Пробег на момент постановки локомотива на СО от последнего аналогичного ремонта]
				, aj.RPAYHRMORGANIZATIONID																as [Фильтр подразделения]
				, dateadd(hh,CAST('$(UTC_OFFSET)' AS int), aj.REGISTRATIONSODATE)										as [Фильтр даты]
				, cte1.Customer																			as [Заказчик]
				, cte2.Executor																			as [Исполнитель]
		 from [$(DB_SOURCE_NAME)]..SSMARRIVALJOURNALLINE ajl -- Строки журнала прибытия
		 inner join [$(DB_SOURCE_NAME)]..SSMARRIVALJOURNAL aj -- Журнал прибытия
		 on (ajl.ARRIVALJOURNALID = aj.ARRIVALJOURNALID) and (aj.STATUS <> 3) -- статус не равен "аннулирован"
		 left join [$(DB_SOURCE_NAME)]..SSMOBJECTS o -- Объекты обслуживания
		 on ajl.OBJECTID = o.OBJECTID
		 left join [$(DB_SOURCE_NAME)]..SSMSERVICEKINDS sk -- Виды обслуживания
		 on aj.SERVICEKINDID = sk.SERVICEKINDID
		 left join cte3 -- Синтетические виды СО
		 on aj.SERVICEKINDID = cte3.aj_servicekindid
		 left join [$(DB_SOURCE_NAME)]..SSMREGISTRATIONDEPOT rd -- Депо приписки
		 on ajl.REGISTRATIONDEPOTID = rd.REGISTRATIONDEPOTID
		 left join cte1 -- Заказчик
		 on aj.RPAYHRMORGANIZATIONID = cte1.OrgID
		 left join cte2 -- Исполнитель
		 on aj.RPAYHRMORGANIZATIONID = cte2.OrgID
		)
			select 
				row_number() over (order by cte4.[Фильтр даты])											as [№ п/п] -- сортировка по фильтру даты 20210818
				, *
			 from cte4
GO

GO
PRINT N'Update complete.';


GO
