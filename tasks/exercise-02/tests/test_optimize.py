import os
import ast
import _hopper_harness as harness
SUBMISSION = os.environ["SUBMISSION"]
pfad = os.path.join(os.environ["SUBMISSION"], "optimize.py")

def test_optimize_0():
    sim_input = "0\n"
    ex_out = ['42561.166666666664']
    proc = harness.run_program(os.path.join(SUBMISSION, "optimize.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_optimize_float():
    sim_input = "0.5\n"
    ex_out = ['42624.854166666664']
    proc = harness.run_program(os.path.join(SUBMISSION, "optimize.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_optimize_negative():
    sim_input = "-1\n"
    ex_out = ['42433.95238095238']
    proc = harness.run_program(os.path.join(SUBMISSION, "optimize.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_optimize_negative_float():
    sim_input = "-0.8\n"
    ex_out = ['42459.37314285715']
    proc = harness.run_program(os.path.join(SUBMISSION, "optimize.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_optimize_one_assignment():
    count = 0
    with open(pfad, 'r') as f:
            tree = ast.parse(f.read())

    for node in ast.walk(tree):
         if isinstance(node, ast.Assign) or isinstance(node, ast.AnnAssign):
              count += 1
    assert count == 1, f"only one assignment needed, actually used: {count}"
