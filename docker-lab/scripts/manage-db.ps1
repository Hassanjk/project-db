$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ComposeFile = Join-Path $ScriptDir '..\docker-compose.yml'
$ComposeFile = (Resolve-Path $ComposeFile).Path

function Invoke-Compose {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
  )
  & docker compose -f $ComposeFile @Args
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Error 'docker is required but was not found in PATH.'
  exit 1
}

$running = Invoke-Compose ps --status running --services 2>$null | ForEach-Object { $_.Trim() }
if (-not ($running -contains 'mariadb-demo')) {
  Write-Error "MariaDB is not running. Start it with:`n  docker compose -f `"$ComposeFile`" up -d"
  exit 1
}

$AdminUser = Read-Host 'Admin username'
$AdminPassSecure = Read-Host 'Admin password' -AsSecureString
$AdminPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassSecure)
)

# Restrict admin account to localhost only (blocks phpMyAdmin login).
$adminSql = @"
CREATE USER IF NOT EXISTS '$AdminUser'@'localhost' IDENTIFIED BY '$AdminPass';
GRANT ALL PRIVILEGES ON *.* TO '$AdminUser'@'localhost' WITH GRANT OPTION;
DELETE FROM mysql.user WHERE User='$AdminUser' AND Host NOT IN ('localhost');
FLUSH PRIVILEGES;
"@

Invoke-Compose exec -T mariadb-demo mysql -u $AdminUser -p$AdminPass -e $adminSql

$createUser = Read-Host 'Create a new user? (y/n)'
$doCreate = $false
if ($createUser) {
  $value = $createUser.ToLowerInvariant()
  if ($value -eq 'y' -or $value -eq 'yes') {
    $doCreate = $true
  }
}

if ($doCreate) {
  $NewUser = Read-Host 'New username'
  $NewPassSecure = Read-Host 'New password' -AsSecureString
  $NewPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassSecure)
  )
  $DbName = Read-Host 'Database name'
  $Privs = Read-Host 'Privileges (comma-separated or ALL)'

  $Privs = ($Privs -replace '\s', '')
  if ([string]::IsNullOrWhiteSpace($Privs)) {
    $Privs = 'SELECT,INSERT,UPDATE,DELETE'
  }

  $PrivsUpper = $Privs.ToUpperInvariant()
  if ($PrivsUpper -eq 'ALL' -or $PrivsUpper -eq 'ALLPRIVILEGES') {
    $PrivsSql = 'ALL PRIVILEGES'
  } else {
    $PrivsSql = $Privs
  }

  $allowOther = Read-Host 'Allow this user to connect from other networks? (y/n)'
  $Hosts = @('phpmyadmin-demo')
  if ($allowOther) {
    $value = $allowOther.ToLowerInvariant()
    if ($value -eq 'y' -or $value -eq 'yes') {
      $Hosts += '%'
    }
  }

  foreach ($Host in $Hosts) {
    $sql = @"
CREATE USER IF NOT EXISTS '$NewUser'@'$Host' IDENTIFIED BY '$NewPass';
GRANT $PrivsSql ON ``$DbName``.* TO '$NewUser'@'$Host';
FLUSH PRIVILEGES;
"@

    Invoke-Compose exec -T mariadb-demo mysql -u $AdminUser -p$AdminPass -e $sql
  }
}

Write-Host 'Done.'
