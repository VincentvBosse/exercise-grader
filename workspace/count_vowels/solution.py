"""Example student submission for the count_vowels exercise (correct)."""


def count_vowels(s):
    return sum(1 for c in s if c in "aeiouAEIOU")
