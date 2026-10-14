"""Tests for the is_palindrome exercise.

The student's solution module is made importable as ``solution`` by the
test runner (it preloads ``solution.py`` from the submission directory).
"""

from solution import is_palindrome


def test_true_palindrome():
    assert is_palindrome("racecar") is True


def test_false_palindrome():
    assert is_palindrome("hello") is False


def test_empty_string():
    assert is_palindrome("") is True


def test_single_char():
    assert is_palindrome("a") is True


def test_even_length():
    assert is_palindrome("abba") is True
    assert is_palindrome("abca") is False
