"""Tests for the print_trio exercise, part 2."""

import io
from contextlib import redirect_stdout

from print2 import main


def test_two_lines():
    buf = io.StringIO()
    with redirect_stdout(buf):
        main()
    assert buf.getvalue() == "Zeile 1\nZeile 2\n"


def test_line_count():
    buf = io.StringIO()
    with redirect_stdout(buf):
        main()
    assert len(buf.getvalue().splitlines()) == 2
