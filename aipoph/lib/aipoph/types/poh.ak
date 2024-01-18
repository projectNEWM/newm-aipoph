use aipoph/types.{TimeData} as t
use aipoph/types/oracle.{OracleDatum}
use assist/types.{Token, Wallet}

pub type TestData {
  validity_range: TimeData,
  random: OracleDatum,
  question: Data,
  answer: Data,
  cur_stage: Int,
}

pub type PoHDatum {
  owner: Wallet,
  deposit: Token,
  incentive: Token,
  test_data: TestData,
}

pub fn start_test_datum_validation(a: PoHDatum, b: PoHDatum) -> Bool {
  // the test_data.question is left to change into whatever here
  and {
    // owner cant change
    a.owner == b.owner,
    // deposit cant change
    a.deposit == b.deposit,
    // incentive cant change
    a.incentive == b.incentive,
    // must have non zero amount
    a.deposit.amt > 0,
    // the validity must change
    a.test_data.validity_range != b.test_data.validity_range,
    // time must be logical
    t.logical_time_data(b.test_data.validity_range),
    // start at the zeroth stage
    b.test_data.cur_stage == 0,
    // the randomness has to change
    a.test_data.random != b.test_data.random,
  }
}

pub fn end_test_datum_validation(
  a: PoHDatum,
  b: PoHDatum,
  answer: AnswerData,
) -> Bool {
  and {
    // owner cant change
    a.owner == b.owner,
    // deposit cant change
    a.deposit == b.deposit,
    // incentive cant change
    a.incentive == b.incentive,
    // the validitiy range cant change
    a.test_data.validity_range == b.test_data.validity_range,
    // the current stage is zeroth
    a.test_data.cur_stage == 0,
    // the next stage is first
    b.test_data.cur_stage == 1,
    // question cant change
    a.test_data.question == b.test_data.question,
    // the answer has been added to the datum
    b.test_data.answer == answer.answer,
    // the randomness cant change
    a.test_data.random == b.test_data.random,
  }
}

pub type AnswerData {
  answer: Data,
}

pub type PoHLockRedeemer {
  StartTest
  EndTest { answer: AnswerData }
  VerifyTest
  Quit
}

pub type PoHMintRedeemer {
  MintPoHToken
  BurnPoHToken
}
