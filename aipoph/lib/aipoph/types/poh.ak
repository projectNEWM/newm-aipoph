use aipoph/types.{OwnerInfo, TokenInfo}

pub type TimeData {
  start: Int,
  end: Int,
}

pub type TestData {
  validity_range: TimeData,
  question: Data,
  stage: Int,
}

pub type PoHDatum {
  owner: OwnerInfo,
  deposit: TokenInfo,
  test_data: TestData,
}

pub type ProofData {
  answer: Data,
}

pub type PoHRedeemer {
  StartTest
  EndTest { proof: ProofData }
  Advance
  Withdraw
  Quit
}
