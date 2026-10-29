# grader-example

A fresh, minimal, self-contained **grader image** that demonstrates the
`GraderResult` contract for the **deadline grade** stage. It derives from
`codeberg.org/hopper/grader-base:latest` (the shared framework) and adds only a
stage config, task tests, and a demo workspace. It is intentionally free of
compatibility formats, points/scores, and network assumptions.

## Two-stage contract

The platform runs two independent image stages per course (see `docs/build.md`):

| Stage   | Image           | When                                          | Service output        |
| ------- | --------------- | --------------------------------------------- | --------------------- |
| `build` | `builder_image` | Per-commit push to `main` before the deadline | Forgejo commit status |
| `grade` | `grader_image`  | Once the deadline has passed                  | README report         |

This project is the **`grade`** stage reference image. Its sibling
`builder-example/` is the **`build`** stage reference image. Both stages share
the exact same `GraderResult` stdout contract and the same set of env vars (plus
`JOB_KIND`, which is `build` or `grade`). The build service runs this image with
`JOB_KIND=grade` once the deadline has passed and renders the emitted
`GraderResult` into the exercise `README.md` as a final report (build section +
tests section inside the `<!-- hopper:build:start/end -->` region, with complete
untruncated tracebacks). The README contract is defined in `docs/build.md` in
the platform monorepo.

## Relationship to grader-base

This image `FROM codeberg.org/hopper/grader-base:latest`. The base image
provides the framework (`run.py`, `testrunner.py`, `config.py`, `harness.py`),
the canonical `GraderResult` schema, and PyYAML. This image contains **only**:

```
grader-example/
  Dockerfile                 FROM codeberg.org/hopper/grader-base:latest; copies config + tasks + workspace
  .dockerignore
  config.yaml                stage config (ordered steps + tests)
  manifest.yaml              task structure manifest (baked to /hopper/manifest.yaml)
  tasks/
    count_vowels/tests/test_count_vowels.py
    is_palindrome/tests/test_is_palindrome.py
    print_trio/tests/test_print1.py
    print_trio/tests/test_print2.py
    print_trio/tests/test_print3.py
    print_toplevel/tests/test_print1.py
    stdin_read/tests/test_ladder.py
  workspace/                 minimal example submissions (baked into image)
    count_vowels/solution.py
    is_palindrome/solution.py
    print_trio/print1.py      (print_trio has no solution.py - any
    print_trio/print2.py       filenames work; the tests import the
    print_trio/print3.py       print1/print2/print3 modules directly)
    print_toplevel/print1.py   (a bare top-level print, no main() and no
                               __name__ guard; the test runs the file via
                               runpy and reads the source via $SUBMISSION)
    stdin_read/ladder.py       (reads stdin at top level, no main() and no
                               __name__ guard; the import hits EOF and the
                               runner records a non-fatal note, while the
                               test drives the file through the harness
                               with explicit stdin)
  smoke.sh                   build + end-to-end smoke tests
  README.md
```

No `run.py`, `testrunner.py`, `harness.py`, or `grader_result.schema.json` is
duplicated here - they live in `grader-base/`.

## What it does

1. The framework reads env vars supplied by the grading runner: `COURSE`,
   `STUDENT`, `EXERCISE`, `COMMAND_TIMEOUT`, `JOB_KIND` (and an optional
   `WORKSPACE`, default `/workspace`).
2. Resolves the submission at `$WORKSPACE/$EXERCISE`.
3. Executes the `config.yaml` steps in order:
    - **Lint step** - `flake8` over every file in the submission directory with
      `on_failure: continue`, so a lint hit is reported without hiding the
      compile and test results. A lint failure still marks the run as failed.
    - **Compile step** - syntax-checks **every** `.py` file in the submission
      directory in memory (no `.pyc` side effects, so a read-only submission
      directory is fine). On failure, `on_failure: stop` halts and omits tests.
    - **Test step** - runs the bundled tests for that exercise against the
      student's submission using the shared dependency-free test runner. Every
      `.py` file in the submission is imported as a module named by its file
      stem; `solution.py` is not special. Importing executes top-level code, so
      any stray output (top-level prints in the submission, prints in test code)
      is redirected to stderr; stdout carries only the JSON result. A submission
      that reads stdin at top level hits EOF on that import and is reported as a
      non-fatal note in `tests.notes` instead of an `errors` entry, so the tests
      still run and `tests.failure` stays false (see `grader-base/README.md`).
      The runner's JSON output becomes the `tests` member.
4. Emits **exactly one** `GraderResult` JSON object on stdout (the last line).
   All diagnostics go to stderr.
5. Exits `0` for student/step/test failures; exits `2` only for
   invocation/internal errors (missing env, missing submission dir, no bundled
   tests).

No cloning, no network, no secrets, no points.

## Task structure manifest

The image bakes a `manifest.yaml` to `/hopper/manifest.yaml` (see the
Dockerfile). It declares the task structure per exercise in the format the build
service extracts to create missing task headings and tutor boxes in the exercise
README (contract: `docs/build.md` in the platform monorepo):

```yaml
format: 1
exercises:
    count_vowels:
        tasks:
            - key: "1.1"
              title: "Zaehlen der Vokale"
              points: 4
```

Tasks may nest `subtasks` beneath a task:

```yaml
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
```

Top-level tasks render as `##` headings and subtasks as `###` headings, each
with its own per-task tutor box keyed by its `key` (for example
`<!-- hopper:tutor:task=1.2a:start -->`). The schema parses `subtasks` at any
depth, but the renderer maintains one level: deeper subtasks are written when
the parent heading is created and are not looked up again afterwards.

Rules: task and subtask keys are immutable once a task has been graded, adding
tasks is allowed, and an exercise without tasks simply has no `tasks` entry.

## Build

```bash
docker build -t grader-example:latest .
```

The base image `codeberg.org/hopper/grader-base:latest` is pulled from the
Codeberg registry. If the pull fails, build it from a local checkout instead:

```bash
docker build -t codeberg.org/hopper/grader-base:latest ../grader-base
```

## Run

The image is driven entirely by env vars (no command arguments). The submission
must be present at `/workspace/<EXERCISE>`. The image bakes in example
submissions for `count_vowels`, `is_palindrome`, `print_trio`, `print_toplevel`,
and `stdin_read`, so it is demoable without a volume mount; bind-mount a real
submission to override.

```bash
# Demo (uses baked-in example workspace):
docker run --rm \
  -e COURSE=2026WS-eidp \
  -e STUDENT=alice \
  -e EXERCISE=count_vowels \
  -e JOB_KIND=grade \
  grader-example:latest

# Real submission (mount over /workspace):
docker run --rm \
  -e COURSE=2026WS-eidp \
  -e STUDENT=alice \
  -e EXERCISE=count_vowels \
  -e JOB_KIND=grade \
  -v /path/to/submissions:/workspace \
  grader-example:latest
```

Stdout (the only JSON line):

```json
{
	"steps": [
		{
			"name": "lint",
			"logs": ["exit code 0"],
			"failure": false
		},
		{
			"name": "compile",
			"logs": ["exit code 0"],
			"failure": false
		}
	],
	"failure": false,
	"tests": {
		"run": 6,
		"passed": [
			"test_count_vowels.test_basic",
			"test_count_vowels.test_empty",
			"test_count_vowels.test_no_vowels",
			"test_count_vowels.test_all_vowels",
			"test_count_vowels.test_uppercase",
			"test_count_vowels.test_mixed_case"
		],
		"failures": [],
		"errors": [],
		"failure": false
	}
}
```

When the compile step fails, `tests` is omitted. The lint step ran first and
also failed (flake8 reports a syntax error as `E999`):

```json
{
	"steps": [
		{
			"name": "lint",
			"logs": ["exit code 1", "... E999 SyntaxError: ..."],
			"failure": true
		},
		{
			"name": "compile",
			"logs": ["exit code 1", "... SyntaxError ..."],
			"failure": true
		}
	],
	"failure": true
}
```

## GraderResult contract

See `grader-base/README.md` and `grader-base/grader_result.schema.json` for the
canonical contract. Emitted as the **last stdout line**; diagnostics must go to
stderr. There are no `points`/`score`/`grade` fields anywhere.

## Environment variables

| Var                    | Required | Default      | Purpose                                                                                                                                                                                |
| ---------------------- | -------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EXERCISE`             | yes      | -            | Selects `$WORKSPACE/$EXERCISE` + bundled tests.                                                                                                                                        |
| `COURSE`               | no       | `""`         | Identification / diagnostics only.                                                                                                                                                     |
| `STUDENT`              | no       | `""`         | Identification / diagnostics only.                                                                                                                                                     |
| `WORKSPACE`            | no       | `/workspace` | Submission root.                                                                                                                                                                       |
| `COMMAND_TIMEOUT`      | no       | `300`        | Per-step timeout in seconds.                                                                                                                                                           |
| `JOB_KIND`             | no       | `""`         | Execution stage; `grade` for this image.                                                                                                                                               |
| `HOPPER_IMPORT_STRICT` | no       | unset        | Opt-in course knob (set it in the image, not by the build service): a top-level `input()` becomes a `tests.errors` entry instead of a `tests.notes` note. See `grader-base/README.md`. |

The build service also passes `GITEA_*` env vars (for images that clone the
student repo). This image is self-contained and does **not** use them.

## Security / runtime

- Runs as a **non-root** user `runner` (UID/GID 1000, inherited from the base
  image).
- **No network** assumptions; the image does not clone or call out.
- **No secrets** are read or required.
- **Stateless**: no data is persisted between runs.
- `COMMAND_TIMEOUT` bounds each step (lint, compile and test) via subprocess
  timeouts.
- The submission directory only needs to be **readable** by UID 1000; nothing is
  written to it.

## Smoke tests

```bash
./grader-example/smoke.sh
```

Ensures the base image is available (building it from the local `../grader-base`
checkout when that exists, so a stale registry or local copy is never reused),
then builds the grader image and runs these scenarios: correct submissions, a
broken solution, a syntax error, missing env, unknown exercise, a mounted
infinite-loop solution that proves `COMMAND_TIMEOUT` is enforced, the baked
`manifest.yaml` shape, a nested-subtask fixture round-trip, the `print_trio`
multi-file submission without `solution.py`, the `print_toplevel` submission
with a bare top-level print (import-time output is redirected to stderr, stdout
stays pure JSON), and the `stdin_read` submission that reads stdin at top level
(non-fatal descriptive import note, tests still run, `failure` stays false) -
validating both exit codes and the `GraderResult` shape against the contract.

## Adding an exercise

1. Create one or more `tasks/<exercise>/tests/test_*.py` files with `test_*`
   functions that import the student's modules by file stem, for example
   `from print1 import main` or `from solution import ...`. To read a submission
   file's source (for `ast`/`inspect` checks) or to run it, build the path from
   `os.environ["SUBMISSION"]` - the process working directory is not the
   submission directory. To assert on a program's printed output, capture it
   explicitly: `contextlib.redirect_stdout` around `runpy.run_path(<file>)` or a
   `main()` call, or
   `subprocess.run([sys.executable, <file>], capture_output=True, text=True)`.
   For a submission that reads stdin, use the harness the base image ships:
   `import _hopper_harness as harness` (the reserved name cannot be shadowed by
   a submission file) and feed stdin explicitly. Importing such a submission
   hits EOF and the runner records a `tests.notes` entry instead of a
   `tests.errors` entry, so the tests still execute. Canonical stdin test
   snippet (the `stdin_read` example follows this pattern):

    ```python
    import os

    import _hopper_harness as harness

    SUBMISSION = os.environ["SUBMISSION"]


    def test_program():
        # Subprocess: program gets "3\n4\n" on stdin, output is captured.
        proc = harness.run_program(os.path.join(SUBMISSION, "ladder.py"), stdin_text="3\n4\n")
        assert proc.returncode == 0
        assert proc.lines == ["5.0"]


    def test_program_in_process():
        # In-process: runpy under a patched sys.stdin; second value is the
        # module globals.
        out, g = harness.run_module(os.path.join(SUBMISSION, "ladder.py"), stdin_text="6\n8\n")
        assert out == "10.0\n"
        assert g["width"] == 6
    ```

2. Add a `tasks` list for the exercise to `manifest.yaml` (each task has `key`,
   `title`, and `points`; optional `subtasks` nest further tasks, see the task
   structure manifest section above).
3. Provide the student's `.py` file(s) at `$WORKSPACE/<exercise>/` - any
   filenames. Each file is imported as a module named by its stem; `solution.py`
   is not special (the `count_vowels`/`is_palindrome` examples use it as their
   single file, `print_trio` uses three files and no `solution.py`).
4. Run with `EXERCISE=<exercise>`.

## `builder_image` / `grader_image` usage

A course configures two image refs in orchestration:

- `builder_image` - the sibling `builder-example` image (or a derivative). The
  build service runs it with `JOB_KIND=build` on every eligible pre-deadline
  push to `main` and publishes the `GraderResult` as a Forgejo commit status.
- `grader_image` - this image (or a course-specific derivative). The build
  service runs it with `JOB_KIND=grade` once the deadline has passed and renders
  the `GraderResult` into the exercise `README.md` (build region with build
  section + tests section with complete tracebacks and the non-fatal
  `tests.notes` messages, plus the task structure from `/hopper/manifest.yaml`).
  The report is written **even if the build fails** - a failed build is itself
  reportable content.

Both image refs are opaque strings to the build service; it runs `docker run`
with the fixed env-var contract and parses the single `GraderResult` JSON from
stdout via `runner.ParseGraderResult`. No changes to the build service are
required to consume either image.
