use aiken/interval.{Finite, NegativeInfinity, PositiveInfinity}
use aiken/transaction.{ValidityRange}
use assist/types.{Token, Wallet}

pub type TimeData {
  start: Int,
  end: Int,
}

pub fn logical_time_data(t: TimeData) -> Bool {
  and {
    t.end >= t.start,
    t.start >= 0,
    t.end >= 0,
  }
}

// Check if the ValidityRange of a transactions exists completely inside
// of a TimeData.
//
pub fn valid_test_entry(t: TimeData, vr: ValidityRange) -> Bool {
  when vr.lower_bound.bound_type is {
    // must be finite
    NegativeInfinity -> False
    // get the lower bound int
    Finite(lower_bound) ->
      when vr.upper_bound.bound_type is {
        // must be finite
        NegativeInfinity -> False
        // get the upper bound int
        Finite(upper_bound) -> and {
            lower_bound >= t.start,
            lower_bound <= t.end,
            upper_bound <= t.end,
            upper_bound >= t.start,
          }
        // must be finite
        PositiveInfinity -> False
      }
    // must be finite
    PositiveInfinity -> False
  }
}

pub type TestData {
  validity_range: TimeData,
  question: Data,
  answer: Data,
  cur_stage: Int,
}

pub type PoHDatum {
  owner: Wallet,
  deposit: Token,
  test_data: TestData,
}

pub fn start_test_datum_validation(a: PoHDatum, b: PoHDatum) -> Bool {
  and {
    // owner cant change
    a.owner == b.owner,
    // deposit cant change
    a.deposit == b.deposit,
    // must have non zero amount
    a.deposit.amt > 0,
    // the validity must change
    a.test_data.validity_range != b.test_data.validity_range,
    // time must be logical
    logical_time_data(b.test_data.validity_range),
    // start at the zeroth stage
    b.test_data.cur_stage == 0,
  }
}

pub fn end_test_datum_validation(
  a: PoHDatum,
  b: PoHDatum,
  proof: ProofData,
) -> Bool {
  and {
    // owner cant change
    a.owner == b.owner,
    // deposit cant change
    a.deposit == b.deposit,
    // the validitiy range cant change
    a.test_data.validity_range == b.test_data.validity_range,
    // the current stage is zeroth
    a.test_data.cur_stage == 0,
    // the next stage is first
    b.test_data.cur_stage == 1,
    // the answer has been added to the datum
    b.test_data.answer == proof.answer,
  }
}

pub type ProofData {
  answer: Data,
}

pub type PoHLockRedeemer {
  StartTest
  EndTest { proof: ProofData }
  VerifyTest
  Quit
}

pub type PoHMintRedeemer {
  MintPohToken
  BurnPoHToken
}
