import json


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