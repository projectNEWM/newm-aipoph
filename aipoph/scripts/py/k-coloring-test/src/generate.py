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

    # Create a spanning tree first to ensure all nodes are connected
    # We'll use a randomized node list and connect them all together
    for i in range(1, len(nodes)):
        G.append((nodes[i - 1], nodes[i]))

    edges_added = N - 1

    # Randomly add the remaining edges
    while edges_added < E:
        u, v = random.sample(nodes, 2)
        if (u, v) not in G and (v, u) not in G:
            G.append((u, v))
            edges_added += 1

    return G
