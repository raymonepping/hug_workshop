#!/usr/bin/env bash
set -euo pipefail

# Colors (safe defaults if terminal not colored)
BOLD=$(tput bold 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)
CYAN=$(tput setaf 6 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
RED=$(tput setaf 1 2>/dev/null || true)

# ===========================
# seed_dataset.sh
# Commands:
#   seed   - Decrypts dataset.jsonl.enc and upserts into DB
#   verify - Prints initials string (first letters in order)
#   clean  - Wipes messages data for reseeding
#
# DBs supported: postgres | mysql | mongo | couchbase
# Containers:    pg | mysql | mongo | couchbase
# Precedence: CLI flags > exported env > .database.env
#
# Flags (order-insensitive):
#   --db-type TYPE
#   --user USER
#   --password PASS
#   --enc-file PATH
#   --passphrase PASS
#   --env FILE
#   --quiet (default) / --verbose
#   verify-only:
#     --limit N
#     --filter "<SQL WHERE>"          (postgres/mysql/couchbase)
#     --match  '<Mongo JSON match>'   (mongo)
# ===========================

usage() {
  cat <<EOF
${BOLD}${CYAN}Usage:${RESET}
  seed_dataset.sh [seed|verify|clean]
                  [--db-type TYPE] [--user USER] [--password PASS]
                  [--enc-file PATH] [--passphrase PASS] [--env FILE]
                  [--quiet|--verbose]
                  [verify: --limit N | --filter "<SQL WHERE>" | --match '<JSON>']

${BOLD}${YELLOW}Verification Gate:${RESET}
  The ${BOLD}verify${RESET} step is intentionally locked.
  Only those holding a valid Vault token may reveal the message.

  To unlock the gate:
      ${GREEN}export VAULT_ADDR="http://127.0.0.1:8200"${RESET}
      ${GREEN}export VAULT_TOKEN="<token with verify-policy>"${RESET}

${BOLD}${CYAN}Examples:${RESET}
  ./seed_dataset.sh seed   --db-type postgres   --user workshop --password workshop
  ./seed_dataset.sh verify --db-type postgres   --limit 32
  ./seed_dataset.sh verify --db-type mysql      --filter "id <= 32"
  ./seed_dataset.sh verify --db-type couchbase  --limit 32
  ./seed_dataset.sh verify --db-type mongo      --match '{ "_id": { "\$lte": 32 } }'
  ./seed_dataset.sh clean  --db-type mongo
EOF
}

die() {
  echo "❌ $*" >&2
  exit 1
}

# -------- defaults --------
CMD=""
DB_TYPE="${DB_TYPE:-}" # postgres | mysql | mongo | couchbase
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-}"
DB_NAME="${DB_NAME:-workshop}"
DB_USER="${DB_USER:-workshop}"
DB_PASSWORD="${DB_PASSWORD:-}"

PG_CONTAINER="${PG_CONTAINER:-pg}"
MYSQL_CONTAINER="${MYSQL_CONTAINER:-mysql}"
MONGO_CONTAINER="${MONGO_CONTAINER:-mongo}"
CB_CONTAINER="${CB_CONTAINER:-couchbase}"

CB_BUCKET="${CB_BUCKET:-workshop}"
CB_SCOPE="${CB_SCOPE:-app}"
CB_COLLECTION="${CB_COLLECTION:-messages}"

DATASET_ENC="${DATASET_ENC:-dataset.jsonl.enc}"
DATASET_PASSPHRASE="${DATASET_PASSPHRASE:-}"

QUIET="${QUIET:-1}"  # default quiet
LIMIT="${LIMIT:-}"   # verify limit
FILTER="${FILTER:-}" # verify SQL/N1QL WHERE fragment (no 'WHERE')
MATCH="${MATCH:-}"   # verify Mongo match JSON

# -------- capture preset env --------
_pre() {
  for v in DB_TYPE DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD \
    PG_CONTAINER MYSQL_CONTAINER MONGO_CONTAINER CB_CONTAINER \
    CB_BUCKET CB_SCOPE CB_COLLECTION DATASET_ENC DATASET_PASSPHRASE \
    QUIET LIMIT FILTER MATCH; do
    eval "PRE_$v=\"\${$v-}\""
  done
}
_restore_pre() {
  for v in DB_TYPE DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD \
    PG_CONTAINER MYSQL_CONTAINER MONGO_CONTAINER CB_CONTAINER \
    CB_BUCKET CB_SCOPE CB_COLLECTION DATASET_ENC DATASET_PASSPHRASE \
    QUIET LIMIT FILTER MATCH; do
    eval "val=\"\${PRE_$v-}\""
    [[ -n "${val}" ]] && eval "$v=\"\$val\"" || true
  done
}

_pre
if [[ -f ".database.env" ]]; then
  # shellcheck disable=SC1091
  source ".database.env"
fi
_restore_pre

# -------- vault verify lock --------
# VAULT_VERIFY_POLICY="${VAULT_VERIFY_POLICY:-workshop-verify}"  # change if you like
# VAULT_TIMEOUT="${VAULT_TIMEOUT:-3}"

# -------- vault verify lock (configurable) --------
# Optional env:
#   VERIFY_POLICY=workshop-verify   # if set, token must include this policy
#   VAULT_NAMESPACE=admin/whatever  # optional namespace
vault_ok() {
  [[ -n "${VAULT_ADDR:-}" ]] || return 1
  [[ -n "${VAULT_TOKEN:-}" ]] || return 1

  local base="${VAULT_ADDR%/}"
  local ns_hdr=()
  if [[ -n "${VAULT_NAMESPACE:-}" ]]; then
    ns_hdr+=(-H "X-Vault-Namespace: ${VAULT_NAMESPACE}")
  fi

  # 1) health reachable (no auth required)
  curl -sS --max-time 3 "${base}/v1/sys/health" >/dev/null || return 1

  # 2) lookup-self (auth required)
  #    capture body to check policies if VERIFY_POLICY is set
  local body
  if ! body="$(curl -sS --fail --max-time 3 \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    "${ns_hdr[@]}" \
    "${base}/v1/auth/token/lookup-self")"; then
    return 1
  fi

  # If no policy is required, token being valid is enough.
  [[ -n "${VERIFY_POLICY:-}" ]] || return 0

  # Try to find policy in the JSON without jq (portable).
  # We’ll match either "policies":[ ... "workshop-verify" ... ]
  # or "data":{"policies":[...]} depending on response shape.
  local want="\"${VERIFY_POLICY}\""
  echo "$body" | tr -d ' \n' | grep -q '"policies":\[[^]]*'"${want}" || return 1
  return 0
}

guard_verify_or_die() {
  if vault_ok; then
    echo "🔓 Verification unlocked: Vault reachable and token valid."
    echo ""
    return 0
  fi
  if [[ -n "${VERIFY_POLICY:-}" ]]; then
    echo "🔒 Verification locked: Vault unreachable, token invalid, or missing policy '${VERIFY_POLICY}'." >&2
    echo "🪄  Set VAULT_ADDR/VAULT_TOKEN (and VAULT_NAMESPACE if used), and ensure the token has that policy to unlock." >&2
  else
    echo "🔒 Verification locked: Vault unreachable or token invalid." >&2
    echo "🪄  Set VAULT_ADDR/VAULT_TOKEN (and VAULT_NAMESPACE if used) to unlock." >&2
  fi
  exit 1
}

# -------- parser --------
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
  a="${args[$i]}"
  case "$a" in
  seed | verify | clean)
    CMD="$a"
    i=$((i + 1))
    ;;

  --db-type)
    DB_TYPE="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;
  --host)
    DB_HOST="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;
  --port)
    DB_PORT="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;
  --database | --db-name)
    DB_NAME="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;
  --user | -u)
    DB_USER="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;
  --password | -p)
    DB_PASSWORD="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;
  --enc-file)
    DATASET_ENC="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;
  --passphrase)
    DATASET_PASSPHRASE="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;

  --env)
    # shellcheck disable=SC1090
    source "${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;

  --quiet)
    QUIET=1
    i=$((i + 1))
    ;;
  --verbose)
    QUIET=0
    i=$((i + 1))
    ;;

  --limit)
    LIMIT="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;
  --filter)
    FILTER="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;
  --match)
    MATCH="${args[$((i + 1))]:-}"
    i=$((i + 2))
    ;;

  -h | --help)
    usage
    exit 0
    ;;
  --)
    i=$((i + 1))
    break
    ;;
  -*)
    echo "Unknown arg: $a" >&2
    usage
    exit 1
    ;;
  *)
    if [[ -z "$CMD" ]]; then
      CMD="$a"
      i=$((i + 1))
    else
      echo "Unknown token: $a" >&2
      usage
      exit 1
    fi
    ;;
  esac
done
[[ -n "$CMD" ]] || CMD="seed"

[[ -n "${DB_TYPE:-}" ]] || die "DB_TYPE not set. Choose one: postgres | mysql | mongo | couchbase"
case "$DB_TYPE" in postgres | mysql | mongo | couchbase) ;; *) die "Unsupported DB_TYPE: $DB_TYPE" ;; esac

decrypt_to_tmp() {
  local enc="${1:-$DATASET_ENC}"
  [[ -f "$enc" ]] || die "Encrypted dataset not found: $enc"
  local tmp
  tmp="$(mktemp)"
  if [[ -n "$DATASET_PASSPHRASE" ]]; then
    openssl aes-256-cbc -d -salt -pbkdf2 -in "$enc" -out "$tmp" -pass pass:"$DATASET_PASSPHRASE"
  else
    echo "🔐 Enter passphrase to decrypt $enc"
    openssl aes-256-cbc -d -salt -pbkdf2 -in "$enc" -out "$tmp"
  fi
  [[ -s "$tmp" ]] || die "Decryption produced empty output."
  echo "$tmp"
}

# -------- helper: resolve running Couchbase container --------
resolve_cb() {
  if docker ps --format '{{.Names}}' | grep -Fxq "$CB_CONTAINER"; then
    [[ "$QUIET" -eq 0 ]] && echo "ℹ️  CB_CONTAINER resolved: $CB_CONTAINER"
    return 0
  fi
  for name in "$CB_CONTAINER" couchbase_hug couchbase; do
    if docker ps --format '{{.Names}}' | grep -Fxq "$name"; then
      CB_CONTAINER="$name"
      [[ "$QUIET" -eq 0 ]] && echo "ℹ️  CB_CONTAINER auto-set: $CB_CONTAINER"
      return 0
    fi
  done
  die "No running Couchbase container found. Set CB_CONTAINER or start one (e.g., couchbase_hug)."
}

# -------------------------
# SEED
# -------------------------
seed() {
  echo "➡️  Seeding DB_TYPE=${DB_TYPE} DB=${DB_NAME}"
  local tmp_jsonl
  tmp_jsonl="$(decrypt_to_tmp "$DATASET_ENC")"
  trap '[[ -n "${tmp_jsonl:-}" ]] && rm -f "${tmp_jsonl:-}"' RETURN

  local ROWS
  ROWS="$(wc -l <"$tmp_jsonl" | tr -d ' ')"

  case "$DB_TYPE" in
  postgres)
    : "${DB_PORT:=5432}"
    if [[ "$QUIET" -eq 1 ]]; then
      docker exec -i "$PG_CONTAINER" psql -q -X -U "$DB_USER" -d "$DB_NAME" <<'SQL' >/dev/null 2>&1
SET client_min_messages TO error;
CREATE TABLE IF NOT EXISTS messages (
  id    INT PRIMARY KEY,
  idx   INT UNIQUE,
  title TEXT NOT NULL
);
SQL
      while IFS= read -r line; do
        id=$(echo "$line" | sed -E 's/.*"id":([0-9]+).*/\1/')
        idx=$(echo "$line" | sed -E 's/.*"idx":([0-9]+).*/\1/')
        title_raw=$(echo "$line" | sed -E 's/.*"title":"(.*)".*/\1/')
        title_esc=${title_raw//\\/\\\\}
        title_esc=${title_esc//\'/\'\'}
        docker exec "$PG_CONTAINER" psql -q -t -A -X -U "$DB_USER" -d "$DB_NAME" -c \
          "INSERT INTO messages (id, idx, title) VALUES ($id, $idx, '$title_esc')
             ON CONFLICT (id) DO UPDATE SET idx=EXCLUDED.idx, title=EXCLUDED.title;" >/dev/null 2>&1
      done <"$tmp_jsonl"
    else
      docker exec -i "$PG_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" <<'SQL'
CREATE TABLE IF NOT EXISTS messages (
  id    INT PRIMARY KEY,
  idx   INT UNIQUE,
  title TEXT NOT NULL
);
SQL
      while IFS= read -r line; do
        id=$(echo "$line" | sed -E 's/.*"id":([0-9]+).*/\1/')
        idx=$(echo "$line" | sed -E 's/.*"idx":([0-9]+).*/\1/')
        title_raw=$(echo "$line" | sed -E 's/.*"title":"(.*)".*/\1/')
        title_esc=${title_raw//\\/\\\\}
        title_esc=${title_esc//\'/\'\'}
        docker exec "$PG_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c \
          "INSERT INTO messages (id, idx, title) VALUES ($id, $idx, '$title_esc')
             ON CONFLICT (id) DO UPDATE SET idx=EXCLUDED.idx, title=EXCLUDED.title;"
      done <"$tmp_jsonl"
    fi
    ;;
  mysql)
    : "${DB_PORT:=3306}"
    if [[ "$QUIET" -eq 1 ]]; then
      docker exec -i "$MYSQL_CONTAINER" mysql -N -s -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<'SQL' >/dev/null 2>&1
CREATE TABLE IF NOT EXISTS messages (
  id INT NOT NULL,
  idx INT NOT NULL,
  title TEXT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_idx (idx)
) ENGINE=InnoDB;
SQL
      while IFS= read -r line; do
        id=$(echo "$line" | sed -E 's/.*"id":([0-9]+).*/\1/')
        idx=$(echo "$line" | sed -E 's/.*"idx":([0-9]+).*/\1/')
        title_raw=$(echo "$line" | sed -E 's/.*"title":"(.*)".*/\1/')
        title_esc=${title_raw//\\/\\\\}
        title_esc=${title_esc//\'/\'\'}
        docker exec "$MYSQL_CONTAINER" mysql -N -s -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e \
          "INSERT INTO messages (id, idx, title) VALUES ($id, $idx, '$title_esc')
             ON DUPLICATE KEY UPDATE idx=VALUES(idx), title=VALUES(title);" >/dev/null 2>&1
      done <"$tmp_jsonl"
    else
      docker exec -i "$MYSQL_CONTAINER" mysql -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<'SQL'
CREATE TABLE IF NOT EXISTS messages (
  id INT NOT NULL,
  idx INT NOT NULL,
  title TEXT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_idx (idx)
) ENGINE=InnoDB;
SQL
      while IFS= read -r line; do
        id=$(echo "$line" | sed -E 's/.*"id":([0-9]+).*/\1/')
        idx=$(echo "$line" | sed -E 's/.*"idx":([0-9]+).*/\1/')
        title_raw=$(echo "$line" | sed -E 's/.*"title":"(.*)".*/\1/')
        title_esc=${title_raw//\\/\\\\}
        title_esc=${title_esc//\'/\'\'}
        docker exec "$MYSQL_CONTAINER" mysql -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e \
          "INSERT INTO messages (id, idx, title) VALUES ($id, $idx, '$title_esc')
             ON DUPLICATE KEY UPDATE idx=VALUES(idx), title=VALUES(title);"
      done <"$tmp_jsonl"
    fi
    ;;
  mongo)
    : "${DB_PORT:=27017}"
    docker cp "$tmp_jsonl" "$MONGO_CONTAINER":/tmp/dataset.jsonl
    docker exec -i "$MONGO_CONTAINER" bash -lc "cat >/tmp/import.js" <<'JSSCRIPT'
const fs = require('fs');
const path = '/tmp/dataset.jsonl';
const content = fs.readFileSync(path, 'utf8').trim();
if (!content) { printjson({ error: 'dataset.jsonl empty' }); quit(1); }
const lines = content.split('\n');
let processed = 0;
lines.forEach(l => {
  const o = JSON.parse(l);
  db.messages.updateOne(
    { _id: o.id },
    { $set: { idx: o.idx, title: o.title } },
    { upsert: true }
  );
  processed++;
});
if (!(process && process.env && process.env.QUIET === '1')) {
  printjson({ processed });
}
JSSCRIPT
    if [[ "$QUIET" -eq 1 ]]; then
      docker exec -e QUIET=1 -i "$MONGO_CONTAINER" mongosh -u "$DB_USER" -p "$DB_PASSWORD" --authenticationDatabase admin "$DB_NAME" /tmp/import.js >/dev/null 2>&1
    else
      docker exec -i "$MONGO_CONTAINER" mongosh -u "$DB_USER" -p "$DB_PASSWORD" --authenticationDatabase admin "$DB_NAME" /tmp/import.js
    fi
    ;;
  couchbase)
    resolve_cb
    [[ "$QUIET" -eq 0 ]] && echo "ℹ️  Using Couchbase container: $CB_CONTAINER"
    {
      docker exec "$CB_CONTAINER" bash -lc \
        "/opt/couchbase/bin/couchbase-cli collection-manage -c 127.0.0.1 -u $DB_USER -p $DB_PASSWORD \
            --bucket $CB_BUCKET --create-scope $CB_SCOPE || true"
      docker exec "$CB_CONTAINER" bash -lc \
        "/opt/couchbase/bin/couchbase-cli collection-manage -c 127.0.0.1 -u $DB_USER -p $DB_PASSWORD \
            --bucket $CB_BUCKET --create-collection $CB_SCOPE.$CB_COLLECTION || true"
      docker cp "$tmp_jsonl" "$CB_CONTAINER":/tmp/dataset.jsonl
      docker exec "$CB_CONTAINER" bash -lc \
        "/opt/couchbase/bin/cbimport json -c couchbase://127.0.0.1 -u $DB_USER -p $DB_PASSWORD \
            -b $CB_BUCKET -d file:///tmp/dataset.jsonl -f lines \
            -g msg::#ID -t 2 --scope-collection-exp $CB_SCOPE.$CB_COLLECTION"
    } >/dev/null 2>&1
    ;;
  esac

  echo "✅ Seeding complete. ($ROWS rows)"
}

# -------------------------
# VERIFY
# -------------------------
verify() {

  # Helper to wrap a single string into the target JSON:
  emit_json_results() {
    local s="$1"
    # If empty, still emit a valid array with empty string for consistency
    if [[ -z "$s" ]]; then
      printf '{\n  "results": [\n    ""\n  ]\n}\n'
    else
      printf '{\n  "results": [\n    "%s"\n  ]\n}\n' "$s"
    fi
  }

  # Run the backend query per DB and capture the initials into MSG (single line).
  local MSG=""
  local where=""
  local limit=""

  case "$DB_TYPE" in
  postgres)
    [[ -n "${FILTER}" ]] && where="WHERE ${FILTER}"
    [[ -n "${LIMIT}" ]] && limit="LIMIT ${LIMIT}"
    # Single value output, no headers, no padding (-A -t), quiet (-q)
    MSG="$(
      docker exec -i "$PG_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -A -t -q -c \
        "WITH base AS (
  SELECT id, title FROM messages
  ${where}
  ORDER BY id
  ${limit}
)
SELECT string_agg(LEFT(title,1), '' ORDER BY id) FROM base;" |
        tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    )"
    ;;
  mysql)
    [[ -n "${FILTER}" ]] && where="WHERE ${FILTER}"
    [[ -n "${LIMIT}" ]] && limit="LIMIT ${LIMIT}"
    # Suppress password warning via MYSQL_PWD; -N -s for raw, single line
    MSG="$(
      docker exec -e MYSQL_PWD="$DB_PASSWORD" -i "$MYSQL_CONTAINER" \
        mysql -N -s -u"$DB_USER" -D "$DB_NAME" -e \
        "SELECT GROUP_CONCAT(SUBSTRING(title,1,1) ORDER BY id SEPARATOR '') AS msg
 FROM (SELECT id, title FROM messages ${where} ORDER BY id ${limit}) t;" |
        tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    )"
    ;;
  mongo)
    : "${DB_PORT:=27017}"
    docker exec -i "$MONGO_CONTAINER" bash -lc 'cat > /tmp/verify.js << "JSSCRIPT"
const m = process.env.MATCH || "";
const limStr = (process.env.LIMIT || "").trim();
const lim = Number.isFinite(parseInt(limStr,10)) ? parseInt(limStr,10) : 0;

let filter = {};
if (m && m.trim()) {
  try { filter = JSON.parse(m); }
  catch (e) { print("Mongo MATCH JSON parse error: " + e.message); quit(2); }
}

const pipeline = [];
if (Object.keys(filter).length) pipeline.push({ $match: filter });
pipeline.push({ $sort: { _id: 1 } });
if (lim > 0) pipeline.push({ $limit: lim });
pipeline.push(
  { $project: { c: { $substrCP: ["$title", 0, 1] } } },
  { $group: { _id: null, s: { $push: "$c" } } },
  { $project: { _id: 0, msg: { $reduce: { input: "$s", initialValue: "", in: { $concat: ["$$value", "$$this"] } } } } }
);

const r = db.messages.aggregate(pipeline).toArray();
print(r && r.length && r[0] && r[0].msg ? r[0].msg : "");
JSSCRIPT'
    MSG="$(
      docker exec -e MATCH="$MATCH" -e LIMIT="$LIMIT" -i "$MONGO_CONTAINER" \
        mongosh -u "$DB_USER" -p "$DB_PASSWORD" --authenticationDatabase admin "$DB_NAME" \
        --quiet /tmp/verify.js |
        tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    )"
    ;;

  couchbase)
    resolve_cb
    [[ "$QUIET" -eq 0 ]] && echo "ℹ️  Using Couchbase container: $CB_CONTAINER"

    local sub_where=""
    local limit=""
    [[ -n "${FILTER}" ]] && sub_where="WHERE ${FILTER}"
    [[ -n "${LIMIT}" ]] && limit="LIMIT ${LIMIT}"

    # Build the exact working N1QL (same as before, via placeholders).
    local q
    q=$(
      cat <<'SQL'
SELECT RAW REPLACE(REPLACE(REPLACE(
  ENCODE_JSON(
    (SELECT RAW SUBSTR(m.title,0,1)
     FROM __BKT__.__SCP__.__COL__ AS m
     __SUBWHERE__
     ORDER BY m.idx
     __LIMIT__)
  ),
  '["',''),
  '","',''),
  '"]',''
);
SQL
    )
    # Inject identifiers and optional fragments
    local BT='`'
    q="${q//__BKT__/${BT}${CB_BUCKET}${BT}}"
    q="${q//__SCP__/${BT}${CB_SCOPE}${BT}}"
    q="${q//__COL__/${BT}${CB_COLLECTION}${BT}}"
    q="${q//__SUBWHERE__/$sub_where}"
    q="${q//__LIMIT__/$limit}"

    # Execute and capture cbq output (JSON-ish)
    local cbq_json
    cbq_json="$(docker exec "$CB_CONTAINER" /opt/couchbase/bin/cbq \
      -u "$DB_USER" -p "$DB_PASSWORD" -quiet -s "$q")"

    # Normalize whitespace and extract the first string inside "results":[ "..." ]
    # Portable sed (BSD/GNU): returns empty if not found.
    MSG="$(
      printf '%s' "$cbq_json" |
        tr -d '\n' |
        sed -n 's/.*"results"[[:space:]]*:[[:space:]]*\[[[:space:]]*"\([^"]*\)".*/\1/p'
    )"
    ;;

  esac

  # Polished, mythic output
  echo "🛡️  Guardian acknowledged."
  echo "✨ The initials reveal themselves:"
  echo "🔐 Codex: ${MSG}"
}

# -------------------------
# CLEAN
# -------------------------
clean() {
  echo "🧹 Cleaning messages for DB_TYPE=${DB_TYPE} DB=${DB_NAME}"
  case "$DB_TYPE" in
  postgres)
    docker exec -i "$PG_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "TRUNCATE TABLE messages;" >/dev/null
    ;;
  mysql)
    docker exec -i "$MYSQL_CONTAINER" mysql -N -s -u"$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -e "TRUNCATE TABLE messages;" >/dev/null
    ;;
  mongo)
    docker exec -it "$MONGO_CONTAINER" mongosh -u "$DB_USER" -p "$DB_PASSWORD" --authenticationDatabase admin "$DB_NAME" --eval "db.messages.drop()" >/dev/null || true
    ;;
  couchbase)
    resolve_cb
    docker exec "$CB_CONTAINER" \
      /opt/couchbase/bin/cbq -u "$DB_USER" -p "$DB_PASSWORD" -quiet -s "DELETE FROM \`${CB_BUCKET}\`.\`${CB_SCOPE}\`.\`${CB_COLLECTION}\`;" >/dev/null
    ;;
  esac
  echo "✅ Clean complete."
}

# -------------------------
# Dispatch
# -------------------------
case "$CMD" in
seed) seed ;;
verify)
  guard_verify_or_die
  verify
  ;;
clean) clean ;;
-h | --help) usage ;;
*)
  echo "Unknown command: $CMD"
  usage
  exit 1
  ;;
esac
