import random


def generate(N, E, seed_value):
    """
    Generates a randomly connected undirected graph with N nodes and E edges.
    Ensures that every node is connected and there are no isolated nodes.

    Parameters:
    - N (int): Number of nodes.
    - E (int): Number of edges.

    Returns:
    - G (list[(int, int)]): The generated graph.
    """
    # Check for feasibility of E given N
    max_edges = N * (N - 1) // 2
    min_edges = N - 1  # to ensure a connected graph
    if E > max_edges or E < min_edges:
        raise ValueError(
            f"Invalid number of edges for {N} nodes. Allowed range: {min_edges} to {max_edges}.")

    # The graph as a list of tuples of integers, each tuple is an edge and
    # each number is the label for a node.
    G = []
    # Add N nodes
    nodes = [i for i in range(N)]

    # the rng oracle needs to seed the random
    random.seed(seed_value)
    random.shuffle(nodes)

    # create pairs, then triples, then quads, etc until E
    edges_added = 0
    flag = False
    for k in range(1, N):
        for i in range(k, N):
            G.append((nodes[i - k], nodes[i]))
            edges_added += 1
            if edges_added == E:
                flag = True
                break
        if flag is True:
            break

    return G
