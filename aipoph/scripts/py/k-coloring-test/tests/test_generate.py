import pytest
from src.generate import generate


def test_create_graph_with_three_nodes():
    g = generate(3, 3, 0)
    # count from zero, so three minus one
    assert 3 - 1 == max(max(g))


def test_create_graph_with_bad_edges():
    # Test with an invalid hexadecimal string
    # Test with an invalid hexadecimal string
    with pytest.raises(ValueError) as excinfo:
        _ = generate(10, 7, 0)
    assert "Invalid number of edges for 10 nodes. Allowed range: 9 to 45." in str(excinfo.value), "valid error message"


def test_create_graph_with_many_nodes1():
    g = generate(10, 13, 0)
    # Test with an invalid hexadecimal string
    assert max(max(g)) == 10 - 1


def test_create_graph_with_many_nodes2():
    g = generate(100, 130, 0)
    # Test with an invalid hexadecimal string
    assert max(max(g)) == 100 - 1
