#!/usr/bin/env bash
# Smoke tests for the grader image.
#
# Ensures codeberg.org/hopper/grader-base:latest is available (pulls it, or
# builds it from a local checkout of ../grader-base), then builds the grader
# image and runs several scenarios validating the emitted GraderResult JSON
# against the contract. Exits non-zero on any failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_IMAGE="codeberg.org/hopper/grader-base:latest"
BASE_DIR="$(cd "$SCRIPT_DIR/../grader-base" && pwd)"
IMAGE="grader-example:latest"

TMPDIR="$(mktemp -d)"
OUT="$TMPDIR/grader_stdout"
ERR="$TMPDIR/grader_stderr"
trap 'rm -rf "$TMPDIR"' EXIT

green() { printf '\033[32m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

PASS=0
FAIL=0

# validate_json <json-string> <label>
validate_json() {
	local json="$1" label="$2"
	python3 - "$json" "$label" <<'PY' || return 1
import json, sys
json_str, label = sys.argv[1], sys.argv[2]
try:
    obj = json.loads(json_str)
except Exception as e:
    print(f"  {label}: NOT valid JSON: {e}", file=sys.stderr)
    sys.exit(1)
errors = []
if not isinstance(obj, dict):
    errors.append("top-level value is not an object")
else:
    if "steps" not in obj:
        errors.append("missing 'steps'")
    elif not isinstance(obj["steps"], list):
        errors.append("'steps' is not a list")
    else:
        for i, s in enumerate(obj["steps"]):
            if not isinstance(s, dict): errors.append(f"step[{i}] not object")
            elif "name" not in s or "logs" not in s or "failure" not in s:
                errors.append(f"step[{i}] missing name/logs/failure")
            elif not isinstance(s["name"], str):
                errors.append(f"step[{i}].name not string")
            elif not isinstance(s["logs"], list):
                errors.append(f"step[{i}].logs not list")
            elif not all(isinstance(x, str) for x in s["logs"]):
                errors.append(f"step[{i}].logs has non-string element")
            elif not isinstance(s["failure"], bool):
                errors.append(f"step[{i}].failure not bool")
    if "failure" not in obj:
        errors.append("missing top-level 'failure'")
    elif not isinstance(obj["failure"], bool):
        errors.append("top-level 'failure' not bool")
    if "tests" in obj and obj["tests"] is not None:
        t = obj["tests"]
        if not isinstance(t, dict): errors.append("'tests' not object")
        else:
            for k in ("run","passed","failures","errors","failure"):
                if k not in t: errors.append(f"tests missing '{k}'")
            if "run" in t and not isinstance(t["run"], int):
                errors.append("tests.run not int")
            elif "run" in t and t["run"] < 0:
                errors.append("tests.run is negative")
            if "failure" in t and not isinstance(t["failure"], bool):
                errors.append("tests.failure not bool")
            if "passed" in t:
                if not isinstance(t["passed"], list):
                    errors.append("tests.passed not list")
                elif not all(isinstance(x, str) for x in t["passed"]):
                    errors.append("tests.passed has non-string element")
            for k in ("failures","errors"):
                if k in t and isinstance(t[k], list):
                    for j, f in enumerate(t[k]):
                        if not isinstance(f, dict) or "method" not in f or "traceback" not in f:
                            errors.append(f"tests.{k}[{j}] not {{method,traceback}} object")
                        elif not isinstance(f["method"], str) or not isinstance(f["traceback"], str):
                            errors.append(f"tests.{k}[{j}] method/traceback not strings")
            if all(k in t and isinstance(t[k], list) for k in ("passed","failures","errors")) \
               and "run" in t and isinstance(t["run"], int):
                lo = len(t["passed"]) + len(t["failures"])
                hi = lo + len(t["errors"])
                if not (lo <= t["run"] <= hi):
                    errors.append(
                        f"tests.run={t['run']} not in [{lo}, {hi}] "
                        f"(passed+failures={lo}, +errors={hi})"
                    )
            if "failure" in t and isinstance(t["failure"], bool) \
               and all(k in t and isinstance(t[k], list) for k in ("failures","errors")):
                if t["failure"] != (bool(t["failures"]) or bool(t["errors"])):
                    errors.append("tests.failure disagrees with failures/errors emptiness")
    for forbidden in ("points", "score", "grade"):
        if forbidden in obj:
            errors.append(f"forbidden field '{forbidden}' present")
if errors:
    print(f"  {label}: INVALID: " + "; ".join(errors), file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY
}

# validate_manifest <path>
validate_manifest() {
	python3 - "$1" <<'PY' || return 1
import sys
import yaml

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        m = yaml.safe_load(f)
except Exception as e:
    print(f"  manifest: NOT valid YAML: {e}", file=sys.stderr)
    sys.exit(1)

errors = []
if not isinstance(m, dict):
    errors.append("top-level value is not an object")
else:
    if m.get("format") != 1:
        errors.append(f"format is {m.get('format')!r}, expected 1")
    exercises = m.get("exercises")
    if not isinstance(exercises, dict) or not exercises:
        errors.append("'exercises' missing, not an object, or empty")
    else:
        def check_task(t, where):
            if not isinstance(t, dict):
                errors.append(f"{where}: task is not an object")
                return
            key = t.get("key")
            if not isinstance(key, str) or not key:
                errors.append(f"{where}: key missing or not a non-empty string")
            title = t.get("title")
            if not isinstance(title, str) or not title:
                errors.append(f"{where}: title missing or not a non-empty string")
            points = t.get("points")
            if isinstance(points, bool) or not isinstance(points, (int, float)):
                errors.append(f"{where}: points not numeric ({points!r})")
            elif points < 0:
                errors.append(f"{where}: points is negative ({points})")
            for i, st in enumerate(t.get("subtasks") or []):
                check_task(st, f"{where}.subtasks[{i}]")

        for name, ex in exercises.items():
            tasks = ex.get("tasks") if isinstance(ex, dict) else None
            if not isinstance(tasks, list):
                errors.append(f"exercise {name}: missing or invalid 'tasks'")
                continue
            for i, t in enumerate(tasks):
                check_task(t, f"exercise {name}.tasks[{i}]")
if errors:
    print("  manifest: INVALID: " + "; ".join(errors), file=sys.stderr)
    sys.exit(1)
PY
}

# validate_nested_fixture <path>
#
# Best-effort check of the nested subtask path. The real parser and
# validator are Go code in the build repo, which this repo does not depend
# on at test time, so this uses the PyYAML stack the base image ships. It
# proves the fixture is valid YAML with the nested shape and that keys
# round-trip as opaque strings; it does not run the Go validator.
validate_nested_fixture() {
	python3 - "$1" <<'PY' || return 1
import sys
import yaml

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    m = yaml.safe_load(f)
tasks = m["exercises"]["count_vowels"]["tasks"]
parent = next(t for t in tasks if t["key"] == "1.2")
subs = parent["subtasks"]
assert [s["key"] for s in subs] == ["1.2a", "1.2b"], subs
assert subs[0]["title"] == "Kleinschreibung"
assert subs[0]["points"] == 1
# Keys are opaque strings: a dump/load round trip keeps them intact.
rt = yaml.safe_load(yaml.safe_dump(m))
rt_subs = rt["exercises"]["count_vowels"]["tasks"][0]["subtasks"]
assert [s["key"] for s in rt_subs] == ["1.2a", "1.2b"], rt_subs
assert all(isinstance(s["key"], str) for s in rt_subs), rt_subs
PY
}

# run_case <label> <expect_exit> <docker args...>
run_case() {
	local label="$1"
	shift
	local expect_exit="$1"
	shift
	set +e
	docker run --rm "$@" "$IMAGE" >"$OUT" 2>"$ERR"
	RC=$?
	set -e
	if [ "$RC" != "$expect_exit" ]; then
		red "FAIL: $label - exit code $RC (expected $expect_exit)"
		cat "$ERR" >&2 || true
		FAIL=$((FAIL + 1))
		return
	fi
	echo "  stderr tail:" >&2
	tail -n 3 "$ERR" >&2 || true
	if [ "$expect_exit" = "0" ]; then
		if validate_json "$(cat "$OUT")" "$label"; then
			green "PASS: $label (exit $RC)"
			PASS=$((PASS + 1))
		else
			red "FAIL: $label - JSON validation failed"
			FAIL=$((FAIL + 1))
		fi
	else
		green "PASS: $label (exit $RC as expected)"
		PASS=$((PASS + 1))
	fi
}

bold "Ensuring base image $BASE_IMAGE ..."
if ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
	docker pull "$BASE_IMAGE" || {
		if [ -d "$BASE_DIR" ]; then
			red "pull failed, building $BASE_IMAGE from $BASE_DIR"
			docker build -t "$BASE_IMAGE" "$BASE_DIR"
		else
			red "pull failed and $BASE_DIR does not exist"
			exit 1
		fi
	}
fi

bold "Building image $IMAGE ..."
docker build -t "$IMAGE" "$SCRIPT_DIR"

bold "Case 1: count_vowels (correct, baked workspace, JOB_KIND=grade) - expect exit 0, success"
run_case "count_vowels correct" 0 \
	-e COURSE=2026WS-eidp -e STUDENT=alice -e EXERCISE=count_vowels -e JOB_KIND=grade
python3 -c '
import json,sys
o=json.loads(sys.argv[1])
assert o["failure"] is False, "expected overall failure=false"
assert o["steps"][0]["name"]=="compile" and o["steps"][0]["failure"] is False
assert o["tests"]["run"]==6, o["tests"]["run"]
assert len(o["tests"]["passed"])==6, o["tests"]["passed"]
assert o["tests"]["failures"]==[] and o["tests"]["errors"]==[]
assert o["tests"]["failure"] is False
print("  contract checks: ok")
' "$(cat "$OUT")" || {
	red "FAIL: count_vowels contract assertion"
	FAIL=$((FAIL + 1))
}

bold "Case 2: is_palindrome (correct, baked workspace) - expect exit 0, success"
run_case "is_palindrome correct" 0 \
	-e COURSE=2026WS-eidp -e STUDENT=bob -e EXERCISE=is_palindrome -e JOB_KIND=grade
python3 -c '
import json,sys
o=json.loads(sys.argv[1])
assert o["failure"] is False
assert o["tests"]["run"]==5
assert len(o["tests"]["passed"])==5
assert o["tests"]["failure"] is False
print("  contract checks: ok")
' "$(cat "$OUT")" || {
	red "FAIL: is_palindrome contract assertion"
	FAIL=$((FAIL + 1))
}

bold "Case 3: count_vowels with a broken solution (mounted) - expect exit 0, failure"
mkdir -p "$TMPDIR/broken/count_vowels"
cat >"$TMPDIR/broken/count_vowels/solution.py" <<'PY'
def count_vowels(s):
    return 0  # wrong
PY
run_case "count_vowels broken" 0 \
	-e COURSE=2026WS-eidp -e STUDENT=carol -e EXERCISE=count_vowels -e JOB_KIND=grade \
	-v "$TMPDIR/broken:/workspace"
python3 -c '
import json,sys
o=json.loads(sys.argv[1])
assert o["failure"] is True, "expected overall failure=true"
assert o["steps"][0]["failure"] is False, "compile should pass"
assert o["tests"]["failure"] is True
assert o["tests"]["run"]==6
assert len(o["tests"]["failures"])>=1, o["tests"]["failures"]
assert all("traceback" in f and "method" in f for f in o["tests"]["failures"])
print("  contract checks: ok")
' "$(cat "$OUT")" || {
	red "FAIL: broken contract assertion"
	FAIL=$((FAIL + 1))
}

bold "Case 4: syntax error in solution (mounted) - expect exit 0, compile failure, no tests"
mkdir -p "$TMPDIR/syntaxerr/count_vowels"
cat >"$TMPDIR/syntaxerr/count_vowels/solution.py" <<'PY'
def count_vowels(s
    return 0
PY
run_case "syntax error" 0 \
	-e EXERCISE=count_vowels -e JOB_KIND=grade -v "$TMPDIR/syntaxerr:/workspace"
python3 -c '
import json,sys
o=json.loads(sys.argv[1])
assert o["failure"] is True
assert o["steps"][0]["name"]=="compile" and o["steps"][0]["failure"] is True
assert "tests" not in o, "tests must be omitted when compile fails"
print("  contract checks: ok")
' "$(cat "$OUT")" || {
	red "FAIL: syntax contract assertion"
	FAIL=$((FAIL + 1))
}

bold "Case 5: missing EXERCISE env - expect nonzero exit"
run_case "missing EXERCISE" 2 -e COURSE=x -e STUDENT=y -e JOB_KIND=grade

bold "Case 6: unknown exercise (no submission dir) - expect nonzero exit"
run_case "unknown exercise" 2 \
	-e COURSE=x -e STUDENT=y -e EXERCISE=does_not_exist -e JOB_KIND=grade \
	-v "$TMPDIR/broken:/workspace"

bold "Case 7: COMMAND_TIMEOUT enforced (mounted infinite loop) - expect exit 0, failure"
mkdir -p "$TMPDIR/loop/is_palindrome"
cat >"$TMPDIR/loop/is_palindrome/solution.py" <<'PY'
def is_palindrome(s):
    while True:
        pass
PY
run_case "timeout_loop" 0 \
	-e EXERCISE=is_palindrome -e JOB_KIND=grade -e COMMAND_TIMEOUT=2 \
	-v "$TMPDIR/loop:/workspace"
python3 -c '
import json,sys
o=json.loads(sys.argv[1])
assert o["failure"] is True, o
assert "tests" in o, "tests must be present (compile passed, test timed out)"
assert o["tests"]["failure"] is True
assert o["tests"]["run"]==0, o["tests"]["run"]
assert len(o["tests"]["errors"])>=1, o["tests"]["errors"]
assert any("timed out" in e["traceback"] for e in o["tests"]["errors"]), o["tests"]["errors"]
print("  contract checks: ok")
' "$(cat "$OUT")" || {
	red "FAIL: timeout contract assertion"
	FAIL=$((FAIL + 1))
}

bold "Case 8: baked manifest.yaml shape - format 1, exercises, valid tasks"
if validate_manifest "$SCRIPT_DIR/manifest.yaml"; then
	green "PASS: manifest shape"
	PASS=$((PASS + 1))
else
	red "FAIL: manifest shape"
	FAIL=$((FAIL + 1))
fi

bold "Case 9: nested subtasks fixture parses and keys round-trip"
mkdir -p "$TMPDIR/manifest"
cat >"$TMPDIR/manifest/nested.yaml" <<'YAML'
format: 1
exercises:
  count_vowels:
    tasks:
      - key: "1.2"
        title: "Gross- und Kleinschreibung"
        points: 2
        subtasks:
          - key: "1.2a"
            title: "Kleinschreibung"
            points: 1
          - key: "1.2b"
            title: "Grossschreibung"
            points: 1
YAML
if validate_nested_fixture "$TMPDIR/manifest/nested.yaml"; then
	green "PASS: nested subtasks fixture"
	PASS=$((PASS + 1))
else
	red "FAIL: nested subtasks fixture"
	FAIL=$((FAIL + 1))
fi

bold "Case 10: print_trio (multi-file submission, no solution.py, baked workspace) - expect exit 0, success"
run_case "print_trio correct" 0 \
	-e COURSE=2026WS-eidp -e STUDENT=dave -e EXERCISE=print_trio -e JOB_KIND=grade
python3 -c '
import json,sys
o=json.loads(sys.argv[1])
assert o["failure"] is False
assert o["steps"][0]["failure"] is False
assert o["tests"]["run"]==4, o["tests"]["run"]
assert len(o["tests"]["passed"])==4
assert o["tests"]["failure"] is False
print("  contract checks: ok")
' "$(cat "$OUT")" || {
	red "FAIL: print_trio contract assertion"
	FAIL=$((FAIL + 1))
}

bold "Summary"
echo "  passed: $PASS"
echo "  failed: $FAIL"
if [ "$FAIL" -ne 0 ]; then
	red "SMOKE TESTS FAILED"
	exit 1
fi
green "ALL SMOKE TESTS PASSED"
