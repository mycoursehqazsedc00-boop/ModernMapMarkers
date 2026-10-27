#!/bin/bash
# Runs the ModernMapMarkers test kit against the addon in the parent folder.
# Needs a Lua 5.3+ interpreter (texlua, lua5.3, lua5.4). Override with  LUA=lua5.4 ./run_all.sh
# Optional: SEEDS=100 STEPS=300 to size the random-session fuzz.
HERE=$(cd "$(dirname "$0")" && pwd); ADDON=$(dirname "$HERE")
LUA=${LUA:-$(command -v texlua || command -v lua5.4 || command -v lua5.3 || command -v lua)}
SEEDS=${SEEDS:-60}; STEPS=${STEPS:-300}
echo "== scenarios"; fail=0; total=0
for s in $(cat "$HERE/scenarios.txt"); do
  total=$((total+1)); out=$("$LUA" "$HERE/mmrun.lua" "$ADDON" "$s" 2>&1 | grep -E "^RESULT" | head -1)
  case "$out" in *"|PASS|"*) ;; *) fail=$((fail+1)); echo "FAIL $s: ${out:0:300}";; esac
done
echo "scenarios: $total run, $fail failed"
echo "== every map of both continents draws without errors"
errs=$("$LUA" "$HERE/regress.lua" "$ADDON" default 2>&1 | tail -1); echo "$errs"
echo "== random lockout sessions ($SEEDS seeds x $STEPS steps, event-driven and silent clients): icons must match the saved list"
bad=0
for s in $(seq 1 "$SEEDS"); do
  line=$("$LUA" "$HERE/mmfuzz.lua" "$ADDON" "$s" "$STEPS" 2>&1 | grep "^SEED")
  v=$(echo "$line" | sed -n 's/.*violations=\([0-9]*\).*/\1/p'); e=$(echo "$line" | sed -n 's/.*errs=\([0-9]*\).*/\1/p'); l=$(echo "$line" | sed -n 's/.*leakedTimer=\(\w*\).*/\1/p')
  if [ "${v:-1}" != "0" ] || [ "${e:-1}" != "0" ] || [ "$l" != "false" ]; then bad=$((bad+1)); echo "seed $s: $line"; fi
done
echo "sessions with a problem: $bad of $SEEDS"
echo "== random dungeon sessions ($SEEDS seeds x $STEPS steps, with and without ClassicAPI instance info): icons must match an independent model"
badd=0
for s in $(seq 1 "$SEEDS"); do
  line=$("$LUA" "$HERE/mmfuzz2.lua" "$ADDON" "$s" "$STEPS" 2>&1 | grep "^SEED")
  v=$(echo "$line" | sed -n 's/.*violations=\([0-9]*\).*/\1/p'); e=$(echo "$line" | sed -n 's/.*errs=\([0-9]*\).*/\1/p')
  if [ "${v:-1}" != "0" ] || [ "${e:-1}" != "0" ]; then badd=$((badd+1)); echo "seed $s: $line"; fi
done
echo "sessions with a problem: $badd of $SEEDS"
[ $fail -eq 0 ] && [ $bad -eq 0 ] && [ $badd -eq 0 ] && [ "$errs" = "errors: 0" ] && echo "ALL GOOD" || { echo "PROBLEMS FOUND"; exit 1; }
