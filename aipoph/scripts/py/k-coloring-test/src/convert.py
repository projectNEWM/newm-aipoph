import hashlib
import json


# 9F0001020001FF
def coloring_to_hash(coloring: list[int]) -> str:
    string = "9f"
    for c in coloring:
        string += bytes([c]).hex()
    string += "ff"
    return hashlib.blake2b(bytes.fromhex(string), digest_size=32).hexdigest()


def graph_to_hash(graph):
    if len(graph) == 0:
        encoded_graph = bytearray([0x80])
    else:
        encoded_graph = bytearray([0x9f])  # Start of an indefinite-length array
        for edge in graph:
            # Start of a tagged array (tag value 121, hence 0xd879) + indefinite-length array
            encoded_edge = bytearray([0xd8, 0x79, 0x9f])
            # Add both vertices of the edge, assuming they fit in a single byte
            encoded_edge.extend(list(edge))
            # End of the array for this edge
            encoded_edge.append(0xff)
            # Append this encoded edge to the graph
            encoded_graph.extend(encoded_edge)
        # End of the graph array
        encoded_graph.append(0xff)
    return hashlib.blake2b(bytes(encoded_graph), digest_size=32).hexdigest()


def edge(begin: int, end: int) -> dict:
    return {
        "constructor": 0,
        "fields": [
            {
                "int": begin
            },
            {
                "int": end
            }
        ]
    }


def to_datum(graph: list[(int, int)]) -> None:
    edges = []
    for (a, b) in graph:
        edges.append(edge(a, b))
    return json.dumps(edges)
