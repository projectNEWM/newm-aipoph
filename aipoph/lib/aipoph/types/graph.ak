use aiken/builtin.{blake2b_256, serialise_data}
use aiken/list

pub type Node =
  Int

pub type Edge {
  begin: Node,
  end: Node,
}

pub type Graph =
  List<Edge>

pub type Color =
  Int

pub type Coloring =
  List<Color>

pub fn coloring_hash(coloring: Coloring) -> ByteArray {
  coloring |> serialise_data |> blake2b_256
}

test color_serialised() {
  let c: Coloring =
    [0, 1, 2, 0, 1]
  ( c |> serialise_data ) == #""
}

test small_coloring_hash() {
  let c: Coloring =
    [0, 1, 2, 0, 1]
  coloring_hash(c) == #"398c36e82ee7a6d7a2bee6fde26fc0c9df373f687b9ec73b5968f9fae8ff92de"
}

pub fn graph_hash(graph: Graph) -> ByteArray {
  graph |> serialise_data |> blake2b_256
}

test graph_serialised() {
  let g: Graph =
    [
      Edge { begin: 2, end: 1 },
      Edge { begin: 1, end: 0 },
      Edge { begin: 0, end: 4 },
      Edge { begin: 4, end: 3 },
      Edge { begin: 3, end: 1 },
      Edge { begin: 2, end: 0 },
      Edge { begin: 4, end: 2 },
    ]
  ( g |> serialise_data ) == #"9fd8799f0201ffd8799f0100ffd8799f0004ffd8799f0403ffd8799f0301ffd8799f0200ffd8799f0402ffff"
}

test empty_graph_graph_hash() {
  graph_hash([]) == #"45b0cfc220ceec5b7c1c62c4d4193d38e4eba48e8815729ce75f9c0ab0e4c1c0"
}

test small_graph_graph_hash() {
  let g: Graph =
    [
      Edge { begin: 2, end: 1 },
      Edge { begin: 1, end: 0 },
      Edge { begin: 0, end: 4 },
      Edge { begin: 4, end: 3 },
      Edge { begin: 3, end: 1 },
      Edge { begin: 2, end: 0 },
      Edge { begin: 4, end: 2 },
    ]
  graph_hash(g) == #"b3064a26269668c85c14d735a77b3b225f5e30ad911870428d3d8daba85e486c"
}

pub fn get_color(coloring: Coloring, node: Int) -> Color {
  do_get_color(coloring, node, 0)
}

fn do_get_color(coloring: Coloring, node: Int, counter: Int) -> Color {
  when coloring is {
    // the node is assigned the non-existent color
    [] -> -1
    // find the color
    [c, ..cs] ->
      if counter == node {
        c
      } else {
        do_get_color(cs, node, counter + 1)
      }
  }
}

pub fn prove_coloring(graph: Graph, coloring: Coloring) -> Bool {
  when graph is {
    // The graph is colored
    [] -> True
    // go edge by edge
    [edge, ..edges] -> {
      let bc: Color = get_color(coloring, edge.begin)
      let ec: Color = get_color(coloring, edge.end)
      if and {
        // cant be the same
        bc == ec,
        // cant be the non-existent color
        bc != -1,
        // cant be the non-existent color
        ec != -1,
      } {
        // two nodes have the same color on an edge or are non-existent
        False
      } else {
        prove_coloring(edges, coloring)
      }
    }
  }
}

// the coloring needs to be between the minimum and the allowed threshold
pub fn prove_minimum(minimum: Int, threshold: Int, coloring: Coloring) -> Bool {
  let k: Int =
    coloring
      |> list.foldl(
           0,
           fn(n, max) {
             if n > max {
               n
             } else {
               max
             }
           },
         )
  minimum + threshold >= k
}

test good_coloring() {
  let g: Graph =
    [
      Edge { begin: 2, end: 1 },
      Edge { begin: 1, end: 0 },
      Edge { begin: 0, end: 4 },
      Edge { begin: 4, end: 3 },
      Edge { begin: 3, end: 1 },
      Edge { begin: 2, end: 0 },
      Edge { begin: 4, end: 2 },
    ]
  let c: Coloring =
    [0, 1, 2, 0, 1]
  prove_coloring(g, c)
}

test good_minimum() {
  let c: Coloring =
    [0, 1, 2, 0, 1]
  prove_minimum(3, 1, c)
}

test bad_color() fail {
  let g: Graph =
    [
      Edge { begin: 2, end: 1 },
      Edge { begin: 1, end: 0 },
      Edge { begin: 0, end: 4 },
      Edge { begin: 4, end: 3 },
      Edge { begin: 3, end: 1 },
      Edge { begin: 2, end: 0 },
      Edge { begin: 4, end: 2 },
    ]
  let c: Coloring =
    [1, 1, 2, 3, 4]
  prove_coloring(g, c)
}

test missing_color() fail {
  let g: Graph =
    [
      Edge { begin: 2, end: 1 },
      Edge { begin: 1, end: 0 },
      Edge { begin: 0, end: 4 },
      Edge { begin: 4, end: 3 },
      Edge { begin: 3, end: 1 },
      Edge { begin: 2, end: 0 },
      Edge { begin: 4, end: 2 },
    ]
  let c: Coloring =
    [1, 1, 3, 4]
  prove_coloring(g, c)
}

test worst_case_good_coloring() {
  let g: Graph =
    [
      Edge { begin: 2, end: 1 },
      Edge { begin: 1, end: 0 },
      Edge { begin: 0, end: 4 },
      Edge { begin: 4, end: 3 },
      Edge { begin: 3, end: 1 },
      Edge { begin: 2, end: 0 },
      Edge { begin: 4, end: 2 },
    ]
  let c: Coloring =
    [0, 1, 2, 3, 4]
  prove_coloring(g, c)
}

test large_graph_coloring() {
  let g: Graph =
    [
      Edge { begin: 14, end: 0 },
      Edge { begin: 0, end: 23 },
      Edge { begin: 23, end: 18 },
      Edge { begin: 18, end: 6 },
      Edge { begin: 6, end: 5 },
      Edge { begin: 5, end: 7 },
      Edge { begin: 7, end: 10 },
      Edge { begin: 10, end: 22 },
      Edge { begin: 22, end: 20 },
      Edge { begin: 20, end: 4 },
      Edge { begin: 4, end: 2 },
      Edge { begin: 2, end: 21 },
      Edge { begin: 21, end: 3 },
      Edge { begin: 3, end: 17 },
      Edge { begin: 17, end: 11 },
      Edge { begin: 11, end: 19 },
      Edge { begin: 19, end: 9 },
      Edge { begin: 9, end: 24 },
      Edge { begin: 24, end: 15 },
      Edge { begin: 15, end: 16 },
      Edge { begin: 16, end: 8 },
      Edge { begin: 8, end: 1 },
      Edge { begin: 1, end: 13 },
      Edge { begin: 13, end: 12 },
      Edge { begin: 13, end: 23 },
      Edge { begin: 8, end: 4 },
      Edge { begin: 11, end: 9 },
      Edge { begin: 18, end: 2 },
      Edge { begin: 3, end: 4 },
      Edge { begin: 7, end: 9 },
      Edge { begin: 19, end: 22 },
      Edge { begin: 0, end: 9 },
      Edge { begin: 14, end: 23 },
      Edge { begin: 13, end: 21 },
      Edge { begin: 16, end: 14 },
      Edge { begin: 15, end: 11 },
      Edge { begin: 4, end: 10 },
      Edge { begin: 13, end: 4 },
      Edge { begin: 1, end: 23 },
      Edge { begin: 7, end: 24 },
      Edge { begin: 10, end: 6 },
      Edge { begin: 9, end: 17 },
      Edge { begin: 23, end: 4 },
      Edge { begin: 18, end: 20 },
      Edge { begin: 9, end: 20 },
      Edge { begin: 1, end: 18 },
      Edge { begin: 9, end: 4 },
      Edge { begin: 15, end: 9 },
      Edge { begin: 24, end: 20 },
      Edge { begin: 17, end: 23 },
      Edge { begin: 15, end: 21 },
      Edge { begin: 4, end: 24 },
      Edge { begin: 10, end: 20 },
      Edge { begin: 5, end: 0 },
      Edge { begin: 15, end: 8 },
      Edge { begin: 22, end: 11 },
    ]

  let c: Coloring =
    [0, 0, 0, 0, 1, 1, 0, 0, 2, 2, 2, 0, 0, 2, 1, 1, 0, 1, 1, 1, 0, 3, 3, 3, 3]
  prove_coloring(g, c)
}
