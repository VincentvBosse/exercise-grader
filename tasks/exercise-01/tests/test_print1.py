import contextlib
import io
import runpy
import ast
import os
pfad = os.path.join(os.environ["SUBMISSION"], "print1.py")

def test_print1_output():
    output_buffer = io.StringIO()

    with contextlib.redirect_stdout(output_buffer):
        runpy.run_path(pfad)

    captured_prints = output_buffer.getvalue()
    assert captured_prints == "Hello World!\n"

def test_print1_no_space():
    with open(pfad, 'r') as f:
        tree = ast.parse(f.read())

    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            assert (' ' not in node.value), f"{node.value} contains a space"
