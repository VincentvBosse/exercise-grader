"""Tests for the stdin_read exercise.

The student's ladder.py reads stdin at top level, so importing it in the
test runner hits EOF (the grader has no stdin). The runner records a
non-fatal note for that and still runs these tests. The tests drive the
program through the harness helpers:

- run_program runs the file as a subprocess with piped stdin and
  captured output;
- run_module executes it in-process under a patched sys.stdin.

The harness ships with the grader base image and is imported under its
reserved name _hopper_harness, which a submission file cannot shadow.
"""

import os

import _hopper_harness as harness

SUBMISSION = os.environ["SUBMISSION"]


def test_ladder_subprocess():
    proc = harness.run_program(os.path.join(SUBMISSION, "ladder.py"), stdin_text="3\n4\n")
    assert proc.returncode == 0
    assert proc.lines == ["5.0"]


def test_ladder_run_module():
    out, g = harness.run_module(os.path.join(SUBMISSION, "ladder.py"), stdin_text="6\n8\n")
    assert out == "10.0\n"
    assert g["width"] == 6
