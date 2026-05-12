 @echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "COMPOSE_FILE=%SCRIPT_DIR%..\docker-compose.yml"
set "PMA_HOST=172.28.0.33"

where docker >nul 2>&1
if errorlevel 1 (
  echo Docker not found in PATH.
  exit /b 1
)

docker compose -f "%COMPOSE_FILE%" ps | findstr "mariadb-demo" >nul
if errorlevel 1 (
  echo MariaDB is not running.
  exit /b 1
)

docker compose -f "%COMPOSE_FILE%" port mariadb-demo 3306 | findstr /r "^0\.0\.0\.0:3306" >nul
if errorlevel 1 (
  echo MariaDB is not bound to 0.0.0.0:3306 on the host.
  echo Check your docker-compose port mapping for the mariadb-demo service.
  exit /b 1
)

echo Enter privileged credentials:
set /p SUPER_USER=User (root): 
set /p SUPER_PASS=Password: 

goto menu


:: =========================================================
:: MENU
:: =========================================================
:menu
echo.
echo ============================================
echo           DATABASE ADMIN MENU
echo ============================================
echo 1 - Create User
echo 2 - Update User
echo 3 - Delete User
echo 4 - Show User Privileges
echo 5 - List Users
echo 6 - Delete All Users (Except Root)
echo 7 - Exit
echo ============================================
set /p CHOICE=Choose: 

if "!CHOICE!"=="1" goto create_user
if "!CHOICE!"=="2" goto update_user
if "!CHOICE!"=="3" goto delete_user
if "!CHOICE!"=="4" goto show_privs
if "!CHOICE!"=="5" goto list_users
if "!CHOICE!"=="6" goto delete_all_users
if "!CHOICE!"=="7" goto end

goto menu


:: =========================================================
:: CREATE USER
:: =========================================================
:create_user
set /p USER=Username: 
set /p PASS=Password: 
set /p DB=Database: 

set "HOSTS=!PMA_HOST!"
set /p EXT=Allow external access? (y/n): 
if /i "!EXT!"=="y" set "HOSTS=!HOSTS! %%"

call :set_privs

for %%H in (!HOSTS!) do (
  call :apply_user "!USER!" "!PASS!" "%%H" "!DB!"
)

goto menu


:: =========================================================
:: UPDATE USER (FIXED VERSION)
:: =========================================================
:update_user
set /p OLD_USER=Current username: 

set /p NEW_USER=New username (or same): 
if "!NEW_USER!"=="" set "NEW_USER=!OLD_USER!"

set /p PASS=New password (empty = keep): 
set /p DB=Database: 

set "HOSTS=!PMA_HOST!"
set /p EXT=Allow external access? (y/n): 
if /i "!EXT!"=="y" set "HOSTS=!HOSTS! %%"

call :set_privs


:: --- rename safely per host ---
if not "!OLD_USER!"=="!NEW_USER!" (
  for %%H in (!HOSTS!) do (
    docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo ^
    mysql -u "!SUPER_USER!" -p"!SUPER_PASS!" ^
    -e "RENAME USER '!OLD_USER!'@'%%H' TO '!NEW_USER!'@'%%H';"
  )
)


:: --- reapply settings ---
for %%H in (!HOSTS!) do (
  call :apply_update "!NEW_USER!" "!PASS!" "%%H" "!DB!"
)

goto menu


:: =========================================================
:: DELETE USER
:: =========================================================
:delete_user
set /p USER=Username to delete: 

set "SQL=DROP USER IF EXISTS '!USER!'@'%%'; DROP USER IF EXISTS '!USER!'@'!PMA_HOST!'; DROP USER IF EXISTS '!USER!'@'localhost'; FLUSH PRIVILEGES;"

docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo ^
mysql -u "!SUPER_USER!" -p"!SUPER_PASS!" -e "!SQL!"

echo User deleted.
goto menu


:: =========================================================
:: APPLY USER (CREATE / UPDATE CORE)
:: =========================================================
:apply_user
set "U=%~1"
set "P=%~2"
set "H=%~3"
set "DB=%~4"

set "SQL=CREATE USER IF NOT EXISTS '!U!'@'!H!' IDENTIFIED BY '!P!';"
set "SQL=!SQL! REVOKE ALL PRIVILEGES, GRANT OPTION FROM '!U!'@'!H!';"
set "SQL=!SQL! GRANT !PRIVS! ON `!DB!`.* TO '!U!'@'!H!';"
set "SQL=!SQL! FLUSH PRIVILEGES;"

docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo ^
mysql -u "!SUPER_USER!" -p"!SUPER_PASS!" -e "!SQL!"

exit /b


:: =========================================================
:: APPLY UPDATE (SAFE VERSION)
:: =========================================================
:apply_update
set "U=%~1"
set "P=%~2"
set "H=%~3"
set "DB=%~4"

set "SQL=CREATE USER IF NOT EXISTS '!U!'@'!H!' IDENTIFIED BY '!P!';"
set "SQL=!SQL! REVOKE ALL PRIVILEGES, GRANT OPTION FROM '!U!'@'!H!';"
set "SQL=!SQL! GRANT !PRIVS! ON `!DB!`.* TO '!U!'@'!H!';"
set "SQL=!SQL! FLUSH PRIVILEGES;"

docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo ^
mysql -u "!SUPER_USER!" -p"!SUPER_PASS!" -e
"!SQL!"

exit /b


:: =========================================================
:: PRIVILEGES
:: =========================================================
:set_privs
echo Privileges:
echo 1=SELECT 2=INSERT 3=UPDATE 4=DELETE 5=CREATE
echo 6=ALTER 7=DROP 8=INDEX 9=EXECUTE 10=ALL
set /p P=Enter: 

set "PRIVS="
set "ALL=0"

for %%X in (!P!) do (
  if "%%X"=="10" set "ALL=1"
)

if "!ALL!"=="1" (
  set "PRIVS=ALL PRIVILEGES"
  exit /b
)

for %%X in (!P!) do (
  if "%%X"=="1" call :add SELECT
  if "%%X"=="2" call :add INSERT
  if "%%X"=="3" call :add UPDATE
  if "%%X"=="4" call :add DELETE
  if "%%X"=="5" call :add CREATE
  if "%%X"=="6" call :add ALTER
  if "%%X"=="7" call :add DROP
  if "%%X"=="8" call :add INDEX
  if "%%X"=="9" call :add EXECUTE
)

exit /b


:add
if defined PRIVS (
  set "PRIVS=!PRIVS!,%~1"
) else (
  set "PRIVS=%~1"
)
exit /b


:: =========================================================
:: SHOW PRIVILEGES (FIXED + STABLE)
:: =========================================================
:show_privs
set /p USER=Username: 

echo.
echo ============================================
echo       USER ACCESS REPORT
echo ============================================
echo User: !USER!
echo.

set "FOUND=0"

call :check_host "!USER!" "localhost"
call :check_host "!USER!" "!PMA_HOST!"
call :check_host "!USER!" "%%"

if "!FOUND!"=="0" echo User not found.

goto menu


:: =========================================================
:: SAFE HOST CHECK (NO BACKTICKS - NO ERRORS)
:: =========================================================
:check_host
set "U=%~1"
set "H=%~2"
set "EXTERNAL_HOST=%%"

set "TMP=%TEMP%\mariadb_check.txt"

docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo ^
mysql -u "!SUPER_USER!" -p"!SUPER_PASS!" -N -s ^
-e "SELECT 1 FROM mysql.user WHERE User='!U!' AND Host='!H!' LIMIT 1;" > "!TMP!"

set "EXISTS="
for /f "usebackq delims=" %%A in ("!TMP!") do set "EXISTS=1"
del "!TMP!" >nul 2>&1

if defined EXISTS (

  set "FOUND=1"

  echo --------------------------------------------
  echo Host: !H!

  if "!H!"=="localhost" echo Access: Local only
  if "!H!"=="!PMA_HOST!" echo Access: Internal network
  if "!H!"=="!EXTERNAL_HOST!" echo Access: External access

  echo.
  echo GRANTS:
  echo --------------------------------------------

  docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo ^
  mysql -u "!SUPER_USER!" -p"!SUPER_PASS!" ^
  -e "SHOW GRANTS FOR '!U!'@'!H!';"

  echo.
)

exit /b


:: =========================================================
:: LIST USERS
:: =========================================================
:list_users
docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo ^
mysql -u "!SUPER_USER!" -p"!SUPER_PASS!" ^
-e "SELECT User, Host FROM mysql.user ORDER BY User, Host;"

goto menu


:: =========================================================
:: DELETE ALL USERS (EXCEPT ROOT + SYSTEM)
:: =========================================================
:delete_all_users
echo.
echo This will delete all users except: root, mariadb.sys, mysql.sys, mysql.session, healthcheck
set /p CONFIRM=Type DELETE to continue: 
if /i not "!CONFIRM!"=="DELETE" goto menu

set "TMP=%TEMP%\mariadb_drop_all.sql"

docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo ^
mysql -u "!SUPER_USER!" -p"!SUPER_PASS!" -N -s ^
-e "SELECT CONCAT('DROP USER IF EXISTS ''',User,'''@''',Host,''';') FROM mysql.user WHERE User NOT IN ('root','mariadb.sys','mysql.sys','mysql.session','healthcheck');" > "!TMP!"

echo FLUSH PRIVILEGES;>> "!TMP!"

docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo ^
mysql -u "!SUPER_USER!" -p"!SUPER_PASS!" < "!TMP!"

del "!TMP!" >nul 2>&1

echo Users deleted.
goto menu


:: =========================================================
:: EXIT
:: =========================================================
:end
echo Bye
endlocal