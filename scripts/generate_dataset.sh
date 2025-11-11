#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

# generate_dataset.sh
# - Creates JSONL dataset with records: {"id":N,"idx":N,"title":"..."}
# - The first letters of K titles (spaces ignored) encode the provided phrase.
# - Controls: total rows, id/idx offset, placement strategy, output file, encryption.
#
# Usage:
#   ./generate_dataset.sh --phrase "WE ARE THE GUARDIANS OF OUR OWN SYSTEMS" \
#                         --count 500 \
#                         [--offset 1] \
#                         [--place start|middle|end|spread] \
#                         [--out dataset.jsonl] \
#                         [--encrypt] [--passphrase PASS] [--force]
#
# Examples:
#   ./generate_dataset.sh --phrase "WE ARE..." --count 500 --encrypt
#   ./generate_dataset.sh --phrase "WE ARE..." --count 500 --offset 101 --place middle
#   ./generate_dataset.sh --phrase "WE ARE..." --count 500 --out custom.jsonl --encrypt --force

OUT="dataset.jsonl"
COUNT=""
PHRASE=""
DO_ENCRYPT=0
PASSPHRASE="${DATASET_PASSPHRASE:-}"
OFFSET=1
PLACE="start"  # start|middle|end|spread
FORCE=0

die(){ echo "❌ $*" >&2; exit 1; }

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --phrase)     PHRASE="${2:-}"; shift 2;;
    --count)      COUNT="${2:-}"; shift 2;;
    --out)        OUT="${2:-}"; shift 2;;
    --encrypt)    DO_ENCRYPT=1; shift;;
    --passphrase) PASSPHRASE="${2:-}"; shift 2;;
    --offset)     OFFSET="${2:-}"; shift 2;;
    --place)      PLACE="${2:-}"; shift 2;;
    --force)      FORCE=1; shift;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# //'; exit 0;;
    *) die "Unknown arg: $1";;
  esac
done

[[ -n "$PHRASE" ]] || die "--phrase is required"
[[ -n "$COUNT"  ]] || die "--count is required"
[[ "$COUNT" =~ ^[0-9]+$ ]] || die "--count must be an integer"
(( COUNT > 0 )) || die "--count must be > 0"
[[ "$OFFSET" =~ ^[0-9]+$ ]] || die "--offset must be a non-negative integer"
[[ "$PLACE" =~ ^(start|middle|end|spread)$ ]] || die "--place must be start|middle|end|spread"

# Protect from accidental overwrite (plain output)
if [[ -f "$OUT" && $FORCE -ne 1 ]]; then
  die "Output exists: $OUT
Use --force to overwrite."
fi

# Strip to A-Z only for initials (ignore spaces/punct)
INITIALS="$(echo "$PHRASE" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z')"
K=${#INITIALS}
(( COUNT >= K )) || die "--count ($COUNT) must be >= number of letters in phrase ($K)"

# Small per-letter words (first word ensures the initial)
declare -A WORDS=(
  [A]="Architects Axioms Arcs Atlas Assembly"
  [B]="Blueprints Bridges Beacons Boundaries Balance"
  [C]="Circuits Chambers Cohesion Compass Constructs"
  [D]="Designs Domains Dials Drift Doctrine"
  [E]="Engines Edges Epochs Echoes Elements"
  [F]="Foundations Frames Facets Flux Forges"
  [G]="Guardians Gears Graphs Gates Guides"
  [H]="Horizons Handles Harbors Helix Habitats"
  [I]="Interfaces Intent Inference Islands Iterations"
  [J]="Junctions Journeys Jigsaws Jetsam Joints"
  [K]="Keystones Kernels Knots Keeps Keys"
  [L]="Ledgers Lattices Layers Links Lenses"
  [M]="Modules Manifests Mantras Meshes Maps"
  [N]="Nodes Networks Notions Niches Navigators"
  [O]="Orbits Operators Origins Orders Outlines"
  [P]="Patterns Pilots Pillars Paths Policies"
  [Q]="Quorums Queries Quanta Quiet Quests"
  [R]="Relays Routines Recipes Rails Realms"
  [S]="Systems Sentinels Schemas Signals Stacks"
  [T]="Topology Transforms Tokens Threads Tenets"
  [U]="Units Umbilicals Upgrades Unions Umbrellas"
  [V]="Vaults Vectors Valves Views Versions"
  [W]="Workflows Wards Weaves Wavelengths Writings"
  [X]="Xylem Xenon X-Paths X-Lines X-Systems"
  [Y]="Yardsticks Yields Yokes Yaw Yarns"
  [Z]="Zones Zettas Zigzags Zeniths Zippers"
)

# Fallback lorem words for filler
LOREM=(Through Static Shadows Every Secret Teaches Responsibility
       Reason Becomes Trust When Proven
       Models of Pattern Align Without Noise
       Calm Control Beats Chaos Consistently
       Design Over Hope Intent Over Accident)

# Deterministic alphabet (avoids brittle {A..Z} parsing)
ALPHABET=(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)

rand(){ od -An -N2 -tu2 < /dev/urandom 2>/dev/null | tr -d ' ' || echo $RANDOM; }

pick_word_for_letter() {
  local L="$1"
  local list="${WORDS[$L]:-}"
  if [[ -z "$list" ]]; then
    echo "${L}—"
    return
  fi
  local n=0; for _ in $list; do n=$((n+1)); done
  local r=$(( $(rand) % n + 1 ))
  local i=1
  for w in $list; do
    if [[ $i -eq $r ]]; then echo "$w"; return; fi
    i=$((i+1))
  done
}

random_tail() {
  # 3–7 random words from LOREM
  local ct=$(( 3 + ($(rand) % 5) ))
  local n=${#LOREM[@]}
  local out=()
  for ((i=0;i<ct;i++)); do
    out+=("${LOREM[$(( $(rand) % n ))]}")
  done
  printf "%s" "${out[*]}"
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  echo "$s"
}

# Decide the positions (indexes in 0..COUNT-1) where the phrase letters land
positions=()
case "$PLACE" in
  start)
    for ((i=0;i<K;i++)); do positions+=("$i"); done
    ;;
  end)
    start_idx=$(( COUNT - K ))
    for ((i=0;i<K;i++)); do positions+=("$((start_idx+i))"); done
    ;;
  middle)
    start_idx=$(( (COUNT - K) / 2 ))
    for ((i=0;i<K;i++)); do positions+=("$((start_idx+i))"); done
    ;;
  spread)
    if (( K == 1 )); then
      positions+=(0)
    else
      for ((i=0;i<K;i++)); do
        pos=$(( i * (COUNT-1) / (K-1) ))
        positions+=("$pos")
      done
    fi
    ;;
esac

# quick set to lookup if index is a phrase position
declare -A IS_PHRASE_POS=()
for ((i=0;i<K;i++)); do IS_PHRASE_POS["${positions[$i]}"]=1; done

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

for ((idx0=0; idx0<COUNT; idx0++)); do
  local_id=$(( OFFSET + idx0 ))
  if [[ -n "${IS_PHRASE_POS[$idx0]:-}" ]]; then
    # Find which letter index matches this position
    letter_i=0
    for ((j=0;j<K;j++)); do
      if [[ "${positions[$j]}" -eq "$idx0" ]]; then letter_i=$j; break; fi
    done
    L="${INITIALS:$letter_i:1}"
    first="$(pick_word_for_letter "$L")"
  else
    # random first letter for filler
    Ltr=$(( $(rand) % 26 ))
    L="${ALPHABET[$Ltr]}"
    first="$(pick_word_for_letter "$L")"
  fi
  tail="$(random_tail)"
  title="$(json_escape "$first $tail")"
  printf '{"id":%d,"idx":%d,"title":"%s"}\n' "$local_id" "$local_id" "$title" >> "$tmp"
done

mv "$tmp" "$OUT"
echo "✅ Wrote $OUT  (rows: $COUNT, encoded letters: $K, offset: $OFFSET, place: $PLACE)"

# Optional encryption
if (( DO_ENCRYPT == 1 )); then
  ENC="${OUT}.enc"
  if [[ -f "$ENC" && $FORCE -ne 1 ]]; then
    die "Encrypted dataset exists: $ENC
Use --force to overwrite."
  fi
  if [[ -z "$PASSPHRASE" ]]; then
    echo "🔐 Enter passphrase to encrypt ${OUT} → ${ENC}"
    openssl aes-256-cbc -salt -pbkdf2 -in "$OUT" -out "$ENC"
  else
    openssl aes-256-cbc -salt -pbkdf2 -in "$OUT" -out "$ENC" -pass pass:"$PASSPHRASE"
  fi
  echo "🗜️  Encrypted → $ENC"
fi
