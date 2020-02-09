
 IF NOT EXISTS
(SELECT
   1
 FROM
   sys.procedures
 WHERE
   name = 'sp_codeCallsCascade'
)
BEGIN
DECLARE @SQL nvarchar(1200);
SET @SQL = N'/*******************************************************************************  
    TodaysDate   AuthorName                     INITIAL STORED PROC STUB CREATE RELEASE
***************************************************************************************/

CREATE PROCEDURE dbo.sp_codeCallsCascade 
AS
     SET NOCOUNT ON;
     
BEGIN
 SELECT 1;
 END;';

EXECUTE SP_EXECUTESQL @SQL;
END;
GO

/*******************************************************************************************************************  
  Object Description: Finds all cascaded code that this piece of code calls
  
  Revision History:
  Date         Name             Label/PTS    Description
  -----------  ---------------  ----------  ----------------------------------------
  2019.06.17   Lisa Bohm                  Initial Release
********************************************************************************************************************/

ALTER PROCEDURE dbo.sp_codeCallsCascade @codeName nvarchar(128)
		, @rootSchema sysname
AS
     SET NOCOUNT ON;
BEGIN
                
IF @rootSchema IS NULL
BEGIN
SET @rootSchema = 'dbo';
END;
 

DECLARE  @root nvarchar(128) = 'root'
		, @rootType nvarchar(60) = 'root';

WITH CallChain AS (
SELECT @root AS callingCode 
		,  o.type_desc AS callObjType
		, 0 as theLevel
		, OBJECT_ID(@rootSchema + '.' + @codeName) AS thisobjID
		,  @rootSchema AS schemaName
		, @codeName AS thisobjName
		, o.type_desc as thisObjType
		, CAST(OBJECT_ID(@codeName)  AS varchar(4000)) AS orderBy
FROM  sys.objects AS o 
		WHERE o.object_id = OBJECT_ID(@codeName) 

UNION ALL 

SELECT	b.thisObjName
		,  o.type_desc 
		, b.theLevel + 1
		, CASE WHEN b.thisObjName = sed.referenced_entity_name THEN 0 ELSE OBJECT_ID(@rootSchema + '.' + referenced_entity_name)  END
		, CASE WHEN b.thisObjName = sed.referenced_entity_name THEN 'LOOP REF'
						WHEN b.orderBy LIKE '%' + CAST(OBJECT_ID(sed.referenced_entity_name) AS varchar(12)) + '%' THEN 'LOOP REF' 
						ELSE COALESCE(sed.referenced_schema_name,'') END 
		, sed.referenced_entity_name 
		, r.type_desc 
		, CAST(CONCAT(b.OrderBy,'-',CAST(OBJECT_ID(referenced_entity_name) AS varchar(12))) AS varchar(4000))
FROM sys.sql_expression_dependencies AS sed  
INNER JOIN sys.objects AS o ON sed.referencing_id = o.object_id 
INNER JOIN sys.objects AS r ON OBJECT_ID(@rootSchema + '.' + referenced_entity_name)  = r.object_id 
INNER JOIN CallChain b ON sed.referencing_id = b.thisObjID
AND (r.type_desc = 'SQL_STORED_PROCEDURE' 
		OR r.type_desc LIKE 'SQL_%' + '%FUNCTION'
		OR r.type_desc = 'VIEW')
AND b.schemaName <> 'LOOP REF'
		)

		SELECT thisObjName
			, thisobjid
			, thisObjType
			, callingCode
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
		, callingCode
		, theLevel
		, schemaName
FROM #callList
ORDER BY orderby;

DROP TABLE #callList;


END;
GO
