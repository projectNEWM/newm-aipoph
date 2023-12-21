use aiken/interval.{Finite, NegativeInfinity, PositiveInfinity}
use aiken/transaction.{ValidityRange}
use aipoph/types.{OwnerInfo, TokenInfo}

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

// the validitiy must exist within the TimeData
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
  tar_stage: Int,
}

pub type PoHDatum {
  owner: OwnerInfo,
  deposit: TokenInfo,
  test_data: TestData,
}

pub fn start_test_datum_validation(a: PoHDatum, b: PoHDatum) -> Bool {
  and {
    a.owner == b.owner,
    a.deposit == b.deposit,
    a.test_data.validity_range != b.test_data.validity_range,
    logical_time_data(b.test_data.validity_range),
    b.test_data.cur_stage == 0,
    b.test_data.tar_stage > 0,
  }
}

pub fn end_test_datum_validation(
  a: PoHDatum,
  b: PoHDatum,
  proof: ProofData,
) -> Bool {
  and {
    a.owner == b.owner,
    a.deposit == b.deposit,
    a.test_data.validity_range == b.test_data.validity_range,
    a.test_data.cur_stage == 0,
    b.test_data.cur_stage == 1,
    a.test_data.tar_stage == b.test_data.tar_stage,
    a.test_data.tar_stage > 0,
    b.test_data.answer == proof.answer,
  }
}

pub type ProofData {
  answer: Data,
}

pub type PoHLockRedeemer {
  StartTest
  EndTest { proof: ProofData }
  Advance
  Withdraw
  Quit
}

pub type PoHMintRedeemer {
  MintToken
  BurnToken
}
