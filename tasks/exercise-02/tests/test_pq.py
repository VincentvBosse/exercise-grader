import os
import _hopper_harness as harness
SUBMISSION = os.environ["SUBMISSION"]

def test_pq_example():
    sim_input = "4.0\n-5.0\n"
    ex_out = ['p = q = x1 = 1.0', 'x2 = -5.0']
    proc = harness.run_program(os.path.join(SUBMISSION, "pq.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_pq_zeros():
    sim_input = "0.0\n0.0\n"
    ex_out = ['p = q = x1 = 0.0', 'x2 = -0.0']
    proc = harness.run_program(os.path.join(SUBMISSION, "pq.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_pq_double_solution():
    sim_input = "-4.0\n4.0\n"
    ex_out = ['p = q = x1 = 2.0', 'x2 = 2.0']
    proc = harness.run_program(os.path.join(SUBMISSION, "pq.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_pq_double_solution_negative():
    sim_input = "4.0\n4.0\n"
    ex_out = ['p = q = x1 = -2.0', 'x2 = -2.0']
    proc = harness.run_program(os.path.join(SUBMISSION, "pq.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_pq_real_solution_1():
    sim_input = "-4.0\n3.0\n"
    ex_out = ['p = q = x1 = 3.0', 'x2 = 1.0']
    proc = harness.run_program(os.path.join(SUBMISSION, "pq.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_pq_real_solution_2():
    sim_input = "0.0\n-4.0\n"
    ex_out = ['p = q = x1 = 2.0', 'x2 = -2.0']
    proc = harness.run_program(os.path.join(SUBMISSION, "pq.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"
