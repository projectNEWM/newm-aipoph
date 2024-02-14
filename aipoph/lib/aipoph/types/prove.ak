//// this will contain all the code for proving humanity.

use aipoph/types/graph.{Coloring, Edge, Graph}
use aipoph/types/signed.{SignedData}
use assist/types/hashes.{PublicKeyHash}

/// The question type will be a graph.
pub type Question {
  graph: Graph,
}

/// The answer to the question will be a coloring to the graph plus two signatures
pub type Answer {
  coloring: Coloring,
  start: SignedData,
  end: SignedData,
}

/// This will be the core function for proof of humanity.
///
/// prove.you_are_a_human(question, answer)
///
pub fn you_are_a_human(question: Question, answer: Answer) -> Bool {
  and {
    // solved the question
    graph.prove_coloring(question.graph, answer.coloring)?,
    // user is signing correct data
    (graph.graph_hash(question.graph) == answer.start.message)?,
    // correct signature
    signed.ed25519(answer.start)?,
    // website is signing correct data
    (graph.coloring_hash(answer.coloring) == answer.end.message)?,
    // correct signature
    signed.ed25519(answer.end)?,
  }
}

test no_you_are_not_a_human() fail {
  let q: Question = Question { graph: [] }
  let sd: SignedData =
    SignedData {
      verification_key: #"0b801082eed269a74c30857bbcf91888865987bb599d00fb9b2f60ba4b58438f",
      message: #"48656c6c6f2c20576f726c6421",
      signature: #"1e55545d89f4e149828f8e3810bffeba9cbb5644d9578cb29592c235ba8945870c305cbd4510811c5aa2b8e71d157a907817c708934b6b9dbab7e0406ccf9e0b",
    }
  let a: Answer = Answer { coloring: [], start: sd, end: sd }
  you_are_a_human(q, a)
}

test yes_you_are_not_a_human() {
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
  let q: Question = Question { graph: g }
  let start: SignedData =
    SignedData {
      verification_key: #"e3bf8fb0f28601d0830d929a308a3e40fdb9f00e5e8272e6008cb785a1fb403b",
      message: #"b3064a26269668c85c14d735a77b3b225f5e30ad911870428d3d8daba85e486c",
      signature: #"1539b9fd090ba61dc5f92ca9421d6f636b25862d66817d26af6daac72bba2f3fb024418b9cf9677d2e4876689e4a4bd97a32868155705997bbbf4cb877661807",
    }
  let end: SignedData =
    SignedData {
      verification_key: #"8611a21e65a62d26795c94d3a2df7ce041d5600ee192100d5478374d1042ad42",
      message: #"398c36e82ee7a6d7a2bee6fde26fc0c9df373f687b9ec73b5968f9fae8ff92de",
      signature: #"79561c678393b703aafcf36638109a41c7acc7043d3ec62342715e97027b0b7175674794f89f316cd09e034c49d77d678978c820960767c3119d763e93e05b0c",
    }
  let a: Answer = Answer { coloring: c, start, end }
  you_are_a_human(q, a)
}

/// Each signature needs to be signed by specific keys.
pub fn correct_signers(
  answer: Answer,
  user: PublicKeyHash,
  website: PublicKeyHash,
) -> Bool {
  and {
    answer.start.verification_key == user,
    answer.end.verification_key == website,
  }
}
