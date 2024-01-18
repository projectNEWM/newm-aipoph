use aiken/interval.{Finite, NegativeInfinity, PositiveInfinity}
use aiken/transaction.{ValidityRange}

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
pub fn valid_time_entry(t: TimeData, vr: ValidityRange) -> Bool {
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
