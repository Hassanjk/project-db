#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
COMPOSE_FILE="$SCRIPT_DIR/../docker-compose.yml"

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but was not found in PATH." >&2
  exit 1
fi

if ! compose ps --status running --services | grep -q "^mariadb-demo$"; then
  echo "MariaDB is not running. Start it with:" >&2
  echo "  docker compose -f \"$COMPOSE_FILE\" up -d" >&2
  exit 1
fi

read -r -p "Admin username: " ADMIN_USER
read -r -s -p "Admin password: " ADMIN_PASS
printf "\n"

# Restrict admin account to localhost only (blocks phpMyAdmin login).
compose exec -T mariadb-demo mysql -u "$ADMIN_USER" -p"$ADMIN_PASS" <<SQL
CREATE USER IF NOT EXISTS '$ADMIN_USER'@'localhost' IDENTIFIED BY '$ADMIN_PASS';
GRANT ALL PRIVILEGES ON *.* TO '$ADMIN_USER'@'localhost' WITH GRANT OPTION;
DELETE FROM mysql.user WHERE User='$ADMIN_USER' AND Host NOT IN ('localhost');
FLUSH PRIVILEGES;
SQL

read -r -p "Create a new user? (y/n): " CREATE_USER
case "${CREATE_USER,,}" in
  y|yes)
    read -r -p "New username: " NEW_USER
    read -r -s -p "New password: " NEW_PASS
    printf "\n"
    read -r -p "Database name: " DB_NAME
    read -r -p "Privileges (comma-separated or ALL): " PRIVS

    PRIVS="${PRIVS// /}"
    if [ -z "$PRIVS" ]; then
      PRIVS="SELECT,INSERT,UPDATE,DELETE"
    fi

    PRIVS_UPPER=$(printf '%s' "$PRIVS" | tr '[:lower:]' '[:upper:]')
    if [ "$PRIVS_UPPER" = "ALL" ] || [ "$PRIVS_UPPER" = "ALLPRIVILEGES" ]; then
      PRIVS_SQL="ALL PRIVILEGES"
    else
      PRIVS_SQL="$PRIVS"
    fi

    read -r -p "Allow this user to connect from other networks? (y/n): " ALLOW_OTHER

    HOSTS=("phpmyadmin-demo")
    case "${ALLOW_OTHER,,}" in
      y|yes) HOSTS+=("%");;
    esac

    for HOST in "${HOSTS[@]}"; do
      compose exec -T mariadb-demo mysql -u "$ADMIN_USER" -p"$ADMIN_PASS" <<SQL
CREATE USER IF NOT EXISTS '$NEW_USER'@'$HOST' IDENTIFIED BY '$NEW_PASS';
GRANT $PRIVS_SQL ON \`$DB_NAME\`.* TO '$NEW_USER'@'$HOST';
FLUSH PRIVILEGES;
SQL
    done
    ;;
esac

echo "Done."
