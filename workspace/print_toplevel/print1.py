"""Example student submission for print_toplevel (correct).

A bare top-level print: no main() function and no __name__ guard. The
test runner imports this file up front, which executes the print; the
runner redirects that stray output to stderr so the JSON result on
stdout stays intact. The test therefore runs the file via runpy and
captures the output explicitly.
"""

print("Hello, World!")
