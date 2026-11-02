
set -euo pipefail

CONTAINER="${CONTAINER:-oracle-ci}"
SERVICE="${SERVICE:-FREEPDB1}"
APP_USER="${APP_USER:-smarthas}"
: "${ORACLE_PASSWORD:?defina ORACLE_PASSWORD}"
: "${APP_PASSWORD:?defina APP_PASSWORD}"

DB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${LOG_DIR:-ci-logs}"
mkdir -p "$LOG_DIR"

CONN_APP="${APP_USER}/${APP_PASSWORD}@//localhost:1521/${SERVICE}"
CONN_SYS="system/${ORACLE_PASSWORD}@//localhost:1521/${SERVICE}"

echo "Aguardando o Oracle ficar pronto (ate 5 minutos)..."
ready=0
for i in $(seq 1 60); do
  if docker logs "$CONTAINER" 2>&1 | grep -q "DATABASE IS READY TO USE!"; then
    ready=1
    break
  fi
  sleep 5
done
if [ "$ready" -ne 1 ]; then
  echo "ERRO: o Oracle nao ficou pronto a tempo. Ultimas linhas do container:"
  docker logs --tail 60 "$CONTAINER" 2>&1 || true
  exit 1
fi
echo "Oracle pronto."


docker exec -i "$CONTAINER" sqlplus -S -L "$CONN_SYS" <<SQL
WHENEVER SQLERROR EXIT FAILURE
GRANT UNLIMITED TABLESPACE TO ${APP_USER};
EXIT
SQL


docker exec "$CONTAINER" mkdir -p /tmp/db
docker cp "$DB_DIR/." "$CONTAINER:/tmp/db/"

run_sql() {
  local script="$1"
  local name
  name="$(basename "${script%.sql}")"
  echo "::group::${script}"
  {
    echo "SET DEFINE OFF"
    echo "SET SQLBLANKLINES ON"
    echo "SET SERVEROUTPUT ON SIZE UNLIMITED"
    echo "SET LINESIZE 220"
    echo "SET PAGESIZE 100"
    echo "@/tmp/db/${script}"
    echo "EXIT"
  } | docker exec -i "$CONTAINER" sqlplus -L -S "$CONN_APP" | tee "$LOG_DIR/${name}.log"
  echo "::endgroup::"
}

for s in 01_ddl.sql 02_dados.sql 03_functions.sql 04_procedures.sql \
         05_packages.sql 06_triggers.sql 07_testes.sql; do
  run_sql "$s"
done

run_sql ci/assert_oracle.sql

echo "Camada Oracle verificada com sucesso."
