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
