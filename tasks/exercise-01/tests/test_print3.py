import contextlib
import io
import runpy
import os
pfad = os.path.join(os.environ["SUBMISSION"], "print3.py")

def test_print3_output():
    output_buffer = io.StringIO()

    with contextlib.redirect_stdout(output_buffer):
        runpy.run_path(pfad)

    captured_prints = output_buffer.getvalue()
    assert captured_prints == "4047\n"