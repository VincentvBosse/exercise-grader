"""Tests for the print_trio exercise, part 1.

The student's print1.py is imported as module ``print1`` by the test
runner (any filenames work; there is no required solution.py).
"""

import io
from contextlib import redirect_stdout

from print1 import main


def test_hello_world():
    buf = io.StringIO()
    with redirect_stdout(buf):
        main()
    assert buf.getvalue() == "Hello, World!\n"
