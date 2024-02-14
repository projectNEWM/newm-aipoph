use aipoph/types/oracle.{OracleDatum}
use aipoph/types/prove.{Answer, Question}
use assist/types/moment.{Moment}
use assist/types/token.{Token}
use assist/types/wallet.{Wallet}

pub type TestData {
  // the test must be taken in this time range
  validity_range: Moment,
  // the random seed for the test
  random: OracleDatum,
  // the question to be answer
  question: Question,
  // the answer to the question
  answer: Answer,
  // the current test stage
  cur_stage: Int,
}

pub type PoHDatum {
  // the owner of the test
  owner: Wallet,
  // the deposit to take the test
  deposit: Token,
  // a unit of incentive to give to threshold actors
  incentive: Token,
  // the lovelace required for the coh token
  min_lovelace: Int,
  // the test data 
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
    // a positive deposit is required
    a.deposit.amt > 0,
    // a positive min lovelace is required
    a.min_lovelace > 0,
    // a positive incentive is required
    a.incentive.amt > 0,
    // the validity must change
    a.test_data.validity_range != b.test_data.validity_range,
    // time must be logical
    moment.is_logical(b.test_data.validity_range),
    // start at the zeroth stage
    b.test_data.cur_stage == 0,
    // the randomness has to change
    a.test_data.random != b.test_data.random,
    // this is the minium lovelace required for the coh token
    a.min_lovelace == b.min_lovelace,
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
  answer: Answer,
}

pub type PoHLockRedeemer {
  StartTest
  EndTest { answer: AnswerData }
  VerifyTest
  Quit
}

pub type PoHMintRedeemer {
  MintPoHToken { complexity: Int }
  BurnPoHToken
}
