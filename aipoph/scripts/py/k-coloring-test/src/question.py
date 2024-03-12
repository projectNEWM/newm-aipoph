import math

from src.coloring import find_minimal_coloring, verify_coloring
from src.generate import generate


def create(n: int, rng: int):
    # this is a parameter
    # a = 1 / (math.e * math.pi)
    a = 1 / (math.e ** math.pi)
    b = 1 - a
    print(a, b)

    e = (-1 + n) * (2 * b + a * n) // 2

    edges = generate(n, e, rng)

    coloring = find_minimal_coloring(edges)
    is_correct = verify_coloring(edges, coloring)
    if is_correct:
        return edges, coloring, max(list(coloring.values())) + 1
    else:
        return create(n, rng + 1)
