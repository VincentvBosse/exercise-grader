"""Example student submission for stdin_read (correct).

Reads the ladder base width and height at TOP LEVEL - no main() function
and no __name__ guard - which is exactly the pattern that used to make an
exercise untestable: the grader has no stdin, so importing this file
raised EOFError and no test ran. The test runner now records a non-fatal
note for that and still runs the tests; the test drives the program
through the harness helpers with explicit stdin.
"""

width = int(input())
height = int(input())
print((width**2 + height**2) ** 0.5)
