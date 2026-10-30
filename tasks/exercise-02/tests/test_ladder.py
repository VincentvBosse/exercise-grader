import os
import _hopper_harness as harness
SUBMISSION = os.environ["SUBMISSION"]

def test_ladder_example_3_1():
    sim_input = "3\n1\n"
    ex_out = ['Breite der Leiter: Anzahl Sprossen: ', '| |', '+-+', '| |', '']
    proc = harness.run_program(os.path.join(SUBMISSION, "ladder.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_ladder_example_9_3():
    sim_input = "9\n3\n"
    ex_out = ['Breite der Leiter: Anzahl Sprossen: ', '|       |', '+-------+', '|       |', '+-------+', '|       |', '+-------+', '|       |', '']
    proc = harness.run_program(os.path.join(SUBMISSION, "ladder.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"

def test_ladder_3_3():
    sim_input = "3\n3\n"
    ex_out = ['Breite der Leiter: Anzahl Sprossen: ', '| |', '+-+', '| |', '+-+', '| |', '+-+', '| |', '']
    proc = harness.run_program(os.path.join(SUBMISSION, "ladder.py"), stdin_text=sim_input)
    captured = proc.lines
    assert captured == ex_out, f"output: {captured} did not match expected output: {ex_out}"
