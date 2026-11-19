/* =============================================================================
   run_all.sql - builds the whole project in one go.

   In SSMS: Query menu -> SQLCMD Mode (must be ON), set the folder below,
   then press F5. Or run the numbered scripts one by one in order.
   ============================================================================= */
:setvar ScriptFolder "C:\Projects\Sales-Analytics-SQLServer\sql"

:r $(ScriptFolder)\00_create_database.sql
:r $(ScriptFolder)\01_schema.sql
:r $(ScriptFolder)\02_sample_data.sql
:r $(ScriptFolder)\03_indexes.sql
:r $(ScriptFolder)\04_views.sql
:r $(ScriptFolder)\07_stored_procedures.sql
:r $(ScriptFolder)\08_data_quality_checks.sql
