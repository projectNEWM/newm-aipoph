import math
import random

from src.coloring import (draw_colored_graph, find_minimal_coloring,
                          verify_coloring)
from src.generate import generate


def test_find_coloring():
    # this is a parameter
    a = 1 / (math.e * math.pi)
    # a = 1 / (math.e ** math.pi)
    # a = 1 / 2
    b = 1 - a
    print(a, b)

    # this is a parameter
    n = 20
    e = (-1 + n) * (2 * b + a * n) // 2
    print(f"A graph wiht {n} nodes and {e} edges")

    rng = random.random()
    rng = 0
    edges = generate(n, e, rng)
    print(edges)

    coloring = find_minimal_coloring(edges)
    is_correct = verify_coloring(edges, coloring)

    print(is_correct)
    print(list(coloring.values()))
    print(max(list(coloring.values())) + 1, 'colors')
    draw_colored_graph(edges, coloring)
