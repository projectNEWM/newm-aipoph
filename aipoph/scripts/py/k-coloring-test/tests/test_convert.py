from src.convert import coloring_to_hash, graph_to_hash


def test_hash_coloring():
    c = [0, 1, 2, 0, 1]
    assert coloring_to_hash(c) == "398c36e82ee7a6d7a2bee6fde26fc0c9df373f687b9ec73b5968f9fae8ff92de"


def test_hash_graph_with_five_nodes():
    g = [
        (2, 1),
        (1, 0),
        (0, 4),
        (4, 3),
        (3, 1),
        (2, 0),
        (4, 2),
    ]
    # count from zero, so three minus one
    assert graph_to_hash(g) == "b3064a26269668c85c14d735a77b3b225f5e30ad911870428d3d8daba85e486c"


def test_hash_empty_graph():
    g = []
    # count from zero, so three minus one
    assert graph_to_hash(g) == "45b0cfc220ceec5b7c1c62c4d4193d38e4eba48e8815729ce75f9c0ab0e4c1c0"