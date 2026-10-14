"""Tests for the count_vowels exercise.

The student's solution module is made importable as ``solution`` by the
test runner (it preloads ``solution.py`` from the submission directory).
"""

from solution import count_vowels


def test_basic():
    assert count_vowels("hello") == 2


def test_empty():
    assert count_vowels("") == 0


def test_no_vowels():
    assert count_vowels("bcdfg") == 0


def test_all_vowels():
    assert count_vowels("aeiou") == 5


def test_uppercase():
    assert count_vowels("HELLO") == 2


def test_mixed_case():
    assert count_vowels("EaSiOo") == 5
