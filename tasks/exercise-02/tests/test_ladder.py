import contextlib
import io
import runpy
import os
from unittest.mock import patch
pfad = os.path.join(os.environ["SUBMISSION"], "ladder.py")

def test_ladder_example_3_1():
    sim_input = "3\n1\n"
    ex_out = "Breite der Leiter: \n Anzahl Prossen: \n\n| |\n|+|\n| |\n"
    with patch('sys.stdin', io.StringIO(sim_input)), patch('sys.stdout', new=io.StringIO()) as fake_stdout:
        runpy.run_path(pfad)

    captured = fake_stdout.getvalue()
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"
