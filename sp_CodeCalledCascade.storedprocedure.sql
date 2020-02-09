
                IF NOT EXISTS
(SELECT
   1
 FROM
   sys.procedures
 WHERE
   name = 'sp_codeCalledCascade'
)
BEGIN
DECLARE @SQL nvarchar(1200);
SET @SQL = N'/*******************************************************************************  
    TodaysDate   AuthorName                     INITIAL STORED PROC STUB CREATE RELEASE
***************************************************************************************/

CREATE PROCEDURE dbo.sp_codeCalledCascade 
AS
     SET NOCOUNT ON;
     
BEGIN
 SELECT 1;
 END;';

EXECUTE SP_EXECUTESQL @SQL;
END;
GO

/*******************************************************************************************************************  
  Object Description: finds cascaded code that calls this code
  
  Revision History:
  Date         Name             Label/PTS    Description
  -----------  ---------------  ----------  ----------------------------------------
  2019.06.17   Lisa Bohm                  Initial Release
********************************************************************************************************************/

ALTER PROCEDURE dbo.sp_codeCalledCascade @codeName nvarchar(128)
		, @rootSchema sysname = 'dbo'
AS
     SET NOCOUNT ON;
BEGIN
                
DECLARE  @root nvarchar(128) = 'root'
		, @rootType nvarchar(60) = 'root';

WITH CallChain AS (
SELECT @root AS calledCode 
		, o.type_desc AS thisObjType
		, 0 as theLevel
		, OBJECT_ID(@rootSchema + '.' + @codeName) AS thisobjID
		, @rootSchema AS schemaName
		, @codeName AS thisobjName
		, CAST(OBJECT_ID(@codeName)  AS varchar(4000)) AS orderBy
FROM  sys.objects AS o 
		WHERE o.object_id = OBJECT_ID(@codeName) 

UNION ALL 

SELECT b.thisobjName
		,  r.type_desc 
		, b.theLevel + 1
		, sed.referencing_id
		, CASE WHEN b.thisobjID = sed.referencing_id THEN 'LOOP REF'
						WHEN b.orderBy LIKE '%' + CAST(sed.referencing_id AS varchar(12)) + '%' THEN 'LOOP REF' 
						ELSE COALESCE(sed.referenced_schema_name,'') END 
		, r.name 
		, CAST(CONCAT(b.OrderBy,'-',CAST(referencing_id AS varchar(12))) AS varchar(4000))
FROM sys.sql_expression_dependencies AS sed  
INNER JOIN sys.objects AS r ON sed.referencing_id  = r.object_id 
INNER JOIN CallChain b ON OBJECT_ID(sed.referenced_entity_name) = b.thisObjID
AND (r.type_desc = 'SQL_STORED_PROCEDURE' 
		OR r.type_desc LIKE 'SQL_%' + '%FUNCTION'
		OR r.type_desc = 'VIEW')
AND b.schemaName <> 'LOOP REF'
		)

		SELECT thisObjName
			, thisobjid
			, thisObjType
			, calledCode
			, theLevel
			, orderBy
			, schemaName
		INTO #callList
		FROM CallChain
		ORDER BY orderby
		OPTION (maxrecursion 200)

		;
SELECT thisObjName
		, thisObjType
		, calledCode
		, theLevel
		, schemaName
FROM #callList
ORDER BY orderby;

DROP TABLE #callList;

END;
GO
