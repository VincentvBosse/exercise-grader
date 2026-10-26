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
provides the framework (`run.py`, `testrunner.py`, `config.py`), the canonical
`GraderResult` schema, and PyYAML. This image contains **only**:

```
grader-example/
  Dockerfile                 FROM codeberg.org/hopper/grader-base:latest; copies config + tasks + workspace
  .dockerignore
  config.yaml                stage config (ordered steps + tests)
  manifest.yaml              task structure manifest (baked to /hopper/manifest.yaml)
  tasks/
    count_vowels/tests/test_count_vowels.py
    is_palindrome/tests/test_is_palindrome.py
  workspace/                 minimal example submissions (baked into image)
    count_vowels/solution.py
    is_palindrome/solution.py
  smoke.sh                   build + end-to-end smoke tests
  README.md
```

No `run.py`, `testrunner.py`, or `grader_result.schema.json` is duplicated
here - they live in `grader-base/`.

## What it does

1. The framework reads env vars supplied by the grading runner: `COURSE`,
   `STUDENT`, `EXERCISE`, `COMMAND_TIMEOUT`, `JOB_KIND` (and an optional
   `WORKSPACE`, default `/workspace`).
2. Resolves the submission at `$WORKSPACE/$EXERCISE`.
3. Executes the `config.yaml` steps in order:
    - **Compile step** - syntax-checks `solution.py` in memory (no `.pyc` side
      effects, so a read-only submission directory is fine). On failure,
      `on_failure: stop` halts and omits tests.
    - **Test step** - runs the bundled tests for that exercise against the
      student's `solution` module using the shared dependency-free test runner.
      The runner's JSON output becomes the `tests` member.
4. Emits **exactly one** `GraderResult` JSON object on stdout (the last line).
   All diagnostics go to stderr.
5. Exits `0` for student/compile/test failures; exits `2` only for
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
submissions for `count_vowels` and `is_palindrome`, so it is demoable without a
volume mount; bind-mount a real submission to override.

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
			"name": "compile",
			"logs": ["exit code 0", "syntax ok"],
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

When the compile step fails, `tests` is omitted:

```json
{
	"steps": [
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

| Var               | Required | Default      | Purpose                                         |
| ----------------- | -------- | ------------ | ----------------------------------------------- |
| `EXERCISE`        | yes      | -            | Selects `$WORKSPACE/$EXERCISE` + bundled tests. |
| `COURSE`          | no       | `""`         | Identification / diagnostics only.              |
| `STUDENT`         | no       | `""`         | Identification / diagnostics only.              |
| `WORKSPACE`       | no       | `/workspace` | Submission root.                                |
| `COMMAND_TIMEOUT` | no       | `300`        | Per-step timeout in seconds.                    |
| `JOB_KIND`        | no       | `""`         | Execution stage; `grade` for this image.        |

The build service also passes `GITEA_*` env vars (for images that clone the
student repo). This image is self-contained and does **not** use them.

## Security / runtime

- Runs as a **non-root** user `runner` (UID/GID 1000, inherited from the base
  image).
- **No network** assumptions; the image does not clone or call out.
- **No secrets** are read or required.
- **Stateless**: no data is persisted between runs.
- `COMMAND_TIMEOUT` bounds each step (compile and test) via subprocess timeouts.
- The submission directory only needs to be **readable** by UID 1000; nothing is
  written to it.

## Smoke tests

```bash
./grader-example/smoke.sh
```

Ensures the base image is available (pull or build from a local `../grader-base`
checkout), then builds the grader image and runs seven scenarios: correct
submissions, a broken solution, a syntax error, missing env, unknown exercise,
and a mounted infinite-loop solution that proves `COMMAND_TIMEOUT` is enforced -
validating both exit codes and the `GraderResult` shape against the contract.

## Adding an exercise

1. Create `tasks/<exercise>/tests/test_<exercise>.py` with `test_*` functions
   that `from solution import ...`.
2. Add a `tasks` list for the exercise to `manifest.yaml` (key, title, points).
3. Provide a student `solution.py` at `$WORKSPACE/<exercise>/solution.py`.
4. Run with `EXERCISE=<exercise>`.

## `builder_image` / `grader_image` usage

A course configures two image refs in orchestration:

- `builder_image` - the sibling `builder-example` image (or a derivative). The
  build service runs it with `JOB_KIND=build` on every eligible pre-deadline
  push to `main` and publishes the `GraderResult` as a Forgejo commit status.
- `grader_image` - this image (or a course-specific derivative). The build
  service runs it with `JOB_KIND=grade` once the deadline has passed and renders
  the `GraderResult` into the exercise `README.md` (build region with build
  section + tests section with complete tracebacks, plus the task structure from
  `/hopper/manifest.yaml`). The report is written **even if the build fails** -
  a failed build is itself reportable content.

Both image refs are opaque strings to the build service; it runs `docker run`
with the fixed env-var contract and parses the single `GraderResult` JSON from
stdout via `runner.ParseGraderResult`. No changes to the build service are
required to consume either image.
