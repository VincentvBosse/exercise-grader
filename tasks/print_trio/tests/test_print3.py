"""Tests for the print_trio exercise, part 3."""

import io
from contextlib import redirect_stdout

from print3 import main


def test_numbers():
    buf = io.StringIO()
    with redirect_stdout(buf):
        main()
    assert buf.getvalue() == "1\n2\n3\n"
