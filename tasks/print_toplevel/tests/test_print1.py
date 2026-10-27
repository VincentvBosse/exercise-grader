"""Tests for the print_toplevel exercise.

The student's print1.py is a bare top-level print - no main() function,
no __name__ guard. Two patterns that work with that:

- run the file via runpy.run_path under redirect_stdout and assert on
  the captured output;
- read the source through the SUBMISSION env var (the working directory
  is NOT the submission directory) and inspect it with ast.

The submission directory is also on sys.path, so function-based
submissions can simply be imported (``from print1 import main``).
"""

import ast
import contextlib
import io
import os
import runpy

SUBMISSION = os.environ["SUBMISSION"]


def test_output():
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        runpy.run_path(os.path.join(SUBMISSION, "print1.py"))
    assert buffer.getvalue() == "Hello, World!\n"


def test_single_string_constant():
    with open(os.path.join(SUBMISSION, "print1.py"), encoding="utf-8") as f:
        tree = ast.parse(f.read())
    # A module docstring is a string constant in the AST too; exclude that
    # node so the check only sees the "real" string literals of the program.
    doc_node = None
    if (
        tree.body
        and isinstance(tree.body[0], ast.Expr)
        and isinstance(tree.body[0].value, ast.Constant)
        and isinstance(tree.body[0].value.value, str)
    ):
        doc_node = tree.body[0].value
    strings = [
        node.value
        for node in ast.walk(tree)
        if isinstance(node, ast.Constant) and isinstance(node.value, str) and node is not doc_node
    ]
    assert strings == ["Hello, World!"]
