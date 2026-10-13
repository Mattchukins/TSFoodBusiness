#!/usr/bin/env bash
set -euo pipefail
# Requires MySQL 8, isolated disposable database and MYSQL_* environment.
: "${MYSQL_HOST:?}" "${MYSQL_USER:?}" "${MYSQL_PASSWORD:?}"
DB="tsfb_stock_ci"
mysql_cmd=(mysql --protocol=tcp -h "$MYSQL_HOST" -u "$MYSQL_USER" "-p$MYSQL_PASSWORD" --batch --skip-column-names)
"${mysql_cmd[@]}" -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB;"
trap '"${mysql_cmd[@]}" -e "DROP DATABASE IF EXISTS tsfb_stock_ci" >/dev/null' EXIT
for file in schema.sql stock_schema.sql stock_procedures.sql; do
  "${mysql_cmd[@]}" "$DB" < "integrations/tsfb-ox-inventory/$file"
done
sql() { "${mysql_cmd[@]}" "$DB" -e "$1"; }
scalar() { sql "$1" | tail -n 1; }
job='12345678-1234-1234-1234-123456789abc'
owner='owner-42'
key='oven|1|bread:2|60|flour:3'
plan='{"outputItem":"bread","outputQuantity":2,"ingredients":[{"item":"flour","quantity":3}]}'
sql "INSERT INTO tsfb_ox_stock(owner_id,item,quantity) VALUES('$owner','flour',10);"
sql "CALL tsfb_stock_reserve('$job','$owner','$key','$plan');" >/dev/null
[[ "$(scalar "SELECT quantity FROM tsfb_ox_stock WHERE owner_id='$owner' AND item='flour'")" == 7 ]]
[[ "$(scalar "SELECT quantity FROM tsfb_ox_escrow WHERE job_id='$job' AND item='flour'")" == 3 ]]
sql "CALL tsfb_stock_reserve('$job','$owner','$key','$plan');" >/dev/null
[[ "$(scalar "SELECT quantity FROM tsfb_ox_stock WHERE owner_id='$owner' AND item='flour'")" == 7 ]]
# Replaying the same job/key with a different plan must not silently succeed.
if sql "CALL tsfb_stock_reserve('$job','$owner','$key','{\"outputItem\":\"bread\",\"outputQuantity\":3,\"ingredients\":[{\"item\":\"flour\",\"quantity\":3}]}');" >/dev/null 2>&1; then
  echo 'ERROR: changed plan accepted on replay' >&2; exit 1
fi
[[ "$(scalar "SELECT quantity FROM tsfb_ox_stock WHERE owner_id='$owner' AND item='flour'")" == 7 ]]
sql "CALL tsfb_stock_commit('$job','$owner','$key');" >/dev/null
sql "CALL tsfb_stock_commit('$job','$owner','$key');" >/dev/null
[[ "$(scalar "SELECT quantity FROM tsfb_ox_stock WHERE owner_id='$owner' AND item='bread'")" == 2 ]]
[[ "$(scalar "SELECT COUNT(*) FROM tsfb_ox_escrow WHERE job_id='$job'")" == 0 ]]
[[ "$(scalar "SELECT COUNT(*) FROM tsfb_ox_production_events WHERE job_id='$job'")" == 2 ]]
job2='87654321-1234-1234-1234-123456789abc'
sql "CALL tsfb_stock_reserve('$job2','$owner','$key','$plan');" >/dev/null
sql "CALL tsfb_stock_release('$job2','$owner','$key');" >/dev/null
sql "CALL tsfb_stock_release('$job2','$owner','$key');" >/dev/null
[[ "$(scalar "SELECT quantity FROM tsfb_ox_stock WHERE owner_id='$owner' AND item='flour'")" == 7 ]]
[[ "$(scalar "SELECT COUNT(*) FROM tsfb_ox_escrow WHERE job_id='$job2'")" == 0 ]]
# Insufficient stock must rollback receipt, audit and all ingredient deductions.
job3='abcdef12-1234-1234-1234-123456789abc'
if sql "CALL tsfb_stock_reserve('$job3','$owner','$key','{\"outputItem\":\"bread\",\"outputQuantity\":2,\"ingredients\":[{\"item\":\"flour\",\"quantity\":8}]}');" >/dev/null 2>&1; then
  echo 'ERROR: insufficient stock was accepted' >&2; exit 1
fi
[[ "$(scalar "SELECT COUNT(*) FROM tsfb_ox_production_receipts WHERE job_id='$job3'")" == 0 ]]
[[ "$(scalar "SELECT quantity FROM tsfb_ox_stock WHERE owner_id='$owner' AND item='flour'")" == 7 ]]
# A mismatched owner must not gain access to a committed receipt.
if sql "CALL tsfb_stock_commit('$job','intruder','$key');" >/dev/null 2>&1; then
  echo 'ERROR: owner mismatch accepted' >&2; exit 1
fi
# A mismatched plan key must not release someone else's escrow.
if sql "CALL tsfb_stock_release('$job2','$owner','different-plan');" >/dev/null 2>&1; then
  echo 'ERROR: plan mismatch accepted' >&2; exit 1
fi
[[ "$(scalar "SELECT quantity FROM tsfb_ox_stock WHERE owner_id='$owner' AND item='bread'")" == 2 ]]
# Duplicate ingredient rows must roll back atomically.
job4='abcdef34-1234-1234-1234-123456789abc'
if sql "CALL tsfb_stock_reserve('$job4','$owner','$key','{\"outputItem\":\"bread\",\"outputQuantity\":2,\"ingredients\":[{\"item\":\"flour\",\"quantity\":1},{\"item\":\"flour\",\"quantity\":1}]}');" >/dev/null 2>&1; then
  echo 'ERROR: duplicate ingredient accepted' >&2; exit 1
fi
[[ "$(scalar "SELECT COUNT(*) FROM tsfb_ox_production_receipts WHERE job_id='$job4'")" == 0 ]]
[[ "$(scalar "SELECT quantity FROM tsfb_ox_stock WHERE owner_id='$owner' AND item='flour'")" == 7 ]]
# Missing receipt must never count as a successful release.
if sql "CALL tsfb_stock_release('99999999-1234-1234-1234-123456789abc','$owner','$key');" >/dev/null 2>&1; then
  echo 'ERROR: missing release receipt accepted' >&2; exit 1
fi
# Invalid output cannot consume ingredients or create a receipt.
bad_job='aaaaaaaa-1234-1234-1234-123456789abc'
if sql "CALL tsfb_stock_reserve('$bad_job','$owner','$key','{\"outputItem\":\"bread\",\"outputQuantity\":0,\"ingredients\":[{\"item\":\"flour\",\"quantity\":1}]}');" >/dev/null 2>&1; then
  echo 'ERROR: zero output accepted' >&2; exit 1
fi
[[ "$(scalar "SELECT COUNT(*) FROM tsfb_ox_production_receipts WHERE job_id='$bad_job'")" == 0 ]]
[[ "$(scalar "SELECT quantity FROM tsfb_ox_stock WHERE owner_id='$owner' AND item='flour'")" == 7 ]]
echo 'MySQL stock reserve/commit/release/replay/rollback integration tests passed'
