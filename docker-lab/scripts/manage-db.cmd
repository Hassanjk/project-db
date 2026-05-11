@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "COMPOSE_FILE=%SCRIPT_DIR%..\docker-compose.yml"

where docker >nul 2>&1
if errorlevel 1 (
  echo docker is required but was not found in PATH.
  exit /b 1
)

for /f "usebackq delims=" %%S in (`docker compose -f "%COMPOSE_FILE%" ps --status running --services`) do (
  if /i "%%S"=="mariadb-demo" set "MARIADB_RUNNING=1"
)

if not defined MARIADB_RUNNING (
  echo MariaDB is not running. Start it with:
  echo   docker compose -f "%COMPOSE_FILE%" up -d
  exit /b 1
)

set /p SUPER_USER=Privileged username (e.g., root): 
set /p SUPER_PASS=Privileged password: 

set /p ADMIN_USER=Admin username to restrict (e.g., demo): 
set /p ADMIN_PASS=Admin password: 

set "ADMIN_SQL=CREATE USER IF NOT EXISTS '!ADMIN_USER!'@'localhost' IDENTIFIED BY '!ADMIN_PASS!'; GRANT ALL PRIVILEGES ON *.* TO '!ADMIN_USER!'@'localhost' WITH GRANT OPTION; DELETE FROM mysql.user WHERE User='!ADMIN_USER!' AND Host NOT IN ('localhost'); FLUSH PRIVILEGES;"

docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo mysql -u "%SUPER_USER%" -p"%SUPER_PASS%" -e "%ADMIN_SQL%"
if errorlevel 1 exit /b 1

echo Create a new user? (y/n):
set /p CREATE_USER=
if /i "%CREATE_USER%"=="y" goto create_user
if /i "%CREATE_USER%"=="yes" goto create_user

goto done

:create_user
set /p NEW_USER=New username: 
set /p NEW_PASS=New password: 
set /p DB_NAME=Database name: 
echo Choose privileges by number (comma-separated):
echo   1=SELECT  2=INSERT  3=UPDATE  4=DELETE  5=CREATE
echo   6=ALTER   7=DROP    8=INDEX   9=EXECUTE 10=ALL
set /p PRIVS_NUM=Enter numbers (default 1,2,3,4): 

if "%PRIVS_NUM%"=="" set "PRIVS_NUM=1,2,3,4"

set "PRIVS_SQL="
set "HAS_ALL="
for %%N in (%PRIVS_NUM%) do (
  if "%%N"=="10" set "HAS_ALL=1"
  if /i "%%N"=="all" set "HAS_ALL=1"
)

if defined HAS_ALL (
  set "PRIVS_SQL=ALL PRIVILEGES"
) else (
  for %%N in (%PRIVS_NUM%) do (
    if "%%N"=="1" call :add_priv SELECT
    if "%%N"=="2" call :add_priv INSERT
    if "%%N"=="3" call :add_priv UPDATE
    if "%%N"=="4" call :add_priv DELETE
    if "%%N"=="5" call :add_priv CREATE
    if "%%N"=="6" call :add_priv ALTER
    if "%%N"=="7" call :add_priv DROP
    if "%%N"=="8" call :add_priv INDEX
    if "%%N"=="9" call :add_priv EXECUTE
  )
)

echo Allow this user to connect from other networks? (y/n):
set /p ALLOW_OTHER=

call :create_user_for_host "phpmyadmin-demo"
if /i "%ALLOW_OTHER%"=="y" call :create_user_for_host "%"
if /i "%ALLOW_OTHER%"=="yes" call :create_user_for_host "%"

goto done

:create_user_for_host
set "HOST=%~1"
set "USER_SQL=CREATE USER IF NOT EXISTS '!NEW_USER!'@'!HOST!' IDENTIFIED BY '!NEW_PASS!'; GRANT !PRIVS_SQL! ON `!DB_NAME!`.* TO '!NEW_USER!'@'!HOST!'; FLUSH PRIVILEGES;"

docker compose -f "%COMPOSE_FILE%" exec -T mariadb-demo mysql -u "%SUPER_USER%" -p"%SUPER_PASS%" -e "%USER_SQL%"
exit /b 0

:add_priv
if defined PRIVS_SQL (
  set "PRIVS_SQL=!PRIVS_SQL!,%~1"
) else (
  set "PRIVS_SQL=%~1"
)
exit /b 0

:done
echo Done.
endlocal
