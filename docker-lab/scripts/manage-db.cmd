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
set /p PRIVS=Privileges (comma-separated or ALL): 

if "%PRIVS%"=="" set "PRIVS=SELECT,INSERT,UPDATE,DELETE"

set "PRIVS_UPPER=%PRIVS%"
for %%A in (ALL ALLPRIVILEGES) do (
  if /i "!PRIVS_UPPER!"=="%%A" set "PRIVS_SQL=ALL PRIVILEGES"
)
if not defined PRIVS_SQL set "PRIVS_SQL=%PRIVS%"

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

:done
echo Done.
endlocal
