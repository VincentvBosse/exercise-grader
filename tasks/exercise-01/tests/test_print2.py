import contextlib
import io
import runpy
import ast
from collections import Counter
import os
pfad = os.path.join(os.environ["SUBMISSION"], "print2.py")

def test_print2_output():
    output_buffer = io.StringIO()

    with contextlib.redirect_stdout(output_buffer):
        runpy.run_path(pfad)

    captured_prints = output_buffer.getvalue()
    assert captured_prints == "AABB\nAABB\nAABB\nAABB\n\n"

def test_print2_symbols_only_once():
    with open(pfad, 'r') as f:
        tree = ast.parse(f.read())

    used_chars = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant):
            if isinstance(node.value, str):
                used_chars.extend(list(node.value))
            elif isinstance(node.value, int):
                used_chars.extend(list(str(node.value)))

    counts = Counter(used_chars)
    for symbol in "AB0123456789":
        assert (counts[symbol] <= 1), f"{symbol} was used more than once"
