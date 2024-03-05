import random


def generate(N: int, E: int, seed_value: int) -> list[(int, int)]:
    """
    Generates a randomly connected undirected graph with N nodes and E edges.
    Ensures that every node is connected and there are no isolated nodes.

    Parameters:
    - N (int): Number of nodes.
    - E (int): Number of edges.
    - seed_value (int): Seed value for randomness.

    Returns:
    - G (list[(int, int)]): The generated graph as a list of edge tuples.
    """
    if E > N * (N - 1) // 2 or E < N - 1:
        raise ValueError(f"Invalid number of edges for {N} nodes. Allowed range: {N - 1} to {N * (N - 1) // 2}.")

    random.seed(seed_value)
    nodes = list(range(N))
    random.shuffle(nodes)

    # Use a set to keep track of added edges for efficient lookup
    edges_set = set()

    # Initial spanning tree to ensure connectivity
    for i in range(1, N):
        edge = (nodes[i - 1], nodes[i])
        edges_set.add(edge)

    # Add additional edges randomly
    while len(edges_set) < E:
        a, b = random.randint(0, N - 1), random.randint(0, N - 1)
        edge = (min(a, b), max(a, b))  # Ensure consistent ordering
        if a != b and edge not in edges_set:
            edges_set.add(edge)

    # Convert set back to a list of tuples for the output
    G = list(edges_set)
    return G
