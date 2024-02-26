import math
import random

from src.coloring import (draw_colored_graph, find_minimal_coloring,
                          verify_coloring)
from src.generate import generate


def test_find_coloring():
    n = 15
    # density
    d = 0.39

    # this is a parameter
    a = (-2 + d * n) / (-2 + n)
    b = 1 - a
    print(a, b)

    # this is a parameter
    # e = int((-1 + n) * (2 * b + a * n) // 2)
    e = int(d * (n*n - n)/2)
    # e = e if e <= n*(n-1)/2 else n*(n-1)/2
    print(
        f"A graph wiht {n} nodes and {e} edges and density {(2 * e) / (n * (n - 1))}")

    rng = random.random()
    edges = generate(n, e, rng)
    print(edges)

    coloring = find_minimal_coloring(edges)
    is_correct = verify_coloring(edges, coloring)

    print(is_correct)
    print(list(coloring.values()))
    print(max(list(coloring.values())) + 1, 'colors')
    draw_colored_graph(edges, coloring)
