import matplotlib.pyplot as plt
import networkx as nx


def is_valid(node, color, graph, node_color):
    # Check if adjacent nodes have the same color
    for neighbor in graph[node]:
        if node_color.get(neighbor) == color:
            return False
    return True


def graph_coloring(graph, m, node=0, node_color={}):
    if node == len(graph):
        return node_color, True  # All nodes are colored

    for color in range(m):
        if is_valid(node, color, graph, node_color):
            node_color[node] = color
            next_node = node + 1
            colors, success = graph_coloring(graph, m, next_node, node_color)
            if success:
                return colors, True
            node_color[node] = None  # Backtrack

    return None, False  # No valid coloring found with m colors


def find_minimal_coloring(edges):
    # Build the graph
    graph = {}
    for edge in edges:
        graph.setdefault(edge[0], []).append(edge[1])
        graph.setdefault(edge[1], []).append(edge[0])

    # Try to color the graph starting from 1 color up to the number of vertices
    max_colors = len(graph) + 1
    for m in range(1, max_colors):
        # print(f"Is The Graph {m}-Colorable?")
        colors, success = graph_coloring(graph, m)
        if success:
            return colors  # Return the coloring and the used number of colors

    return None  # Should never reach here if the graph is valid


def verify_coloring(edges, coloring):
    # Check correctness
    for edge in edges:
        if coloring[edge[0]] == coloring[edge[1]]:
            return False  # Incorrect coloring: adjacent vertices share the same color
    return True


def draw_colored_graph(edges, coloring):
    # Create a graph from edges
    G = nx.Graph()
    G.add_edges_from(edges)

    # Extract color mapping in order appropriate for drawing
    color_map = [coloring[node] for node in G.nodes()]

    # Extract positions for nodes using a layout
    pos = nx.shell_layout(G)
    # pos = nx.arf_layout(G)
    # Draw the graph
    nx.draw(G, pos, node_color=color_map, with_labels=False,
            cmap=plt.cm.jet, edge_color='black')

    # Save the image
    plt.savefig("graph.png")
    # plt.show()
