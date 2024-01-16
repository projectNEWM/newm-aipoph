use aiken/transaction.{DatumHash, InlineDatum, Input}
use aiken/transaction/credential.{Address}

/// The contract can only be spent by itself or with dreps. Loop all the inputs
/// and count how many inline datums belong to this address. If a drep exists
/// then pass right over it but if anything else is found then fail. This
/// should prevent large unregulated luquidity pools as counting as participating
/// in the dao.
///
/// catch.specific_inputs_only(this_tx.inputs, this_addr, drep_addr)
///
pub fn specific_inputs_only(
  inputs: List<Input>,
  this_addr: Address,
  drep_addr: Address,
) -> Bool {
  do_inputs_by_datum_type(inputs, 0, this_addr, drep_addr)
}

// Internal only
fn do_inputs_by_datum_type(
  inputs: List<Input>,
  counter: Int,
  this_addr: Address,
  drep_addr: Address,
) -> Bool {
  when inputs is {
    [input, ..rest] ->
      when input.output.datum is {
        // the actual datum value isn't important here
        InlineDatum(_) ->
          if input.output.address == this_addr {
            do_inputs_by_datum_type(rest, counter + 1, this_addr, drep_addr)
          } else if input.output.address == drep_addr {
            do_inputs_by_datum_type(rest, counter, this_addr, drep_addr)
          } else {
            fail @"Not An Allowed Address On Inline Datum"
          }
        // the actual datum hash isn't important here
        DatumHash(_) ->
          if input.output.address == this_addr {
            do_inputs_by_datum_type(rest, counter + 1, this_addr, drep_addr)
          } else if input.output.address == drep_addr {
            do_inputs_by_datum_type(rest, counter, this_addr, drep_addr)
          } else {
            fail @"Not An Allowed Address On Datum Hash"
          }
        _ -> do_inputs_by_datum_type(rest, counter, this_addr, drep_addr)
      }
    // there can be only 1 dao contract and any amount of dreps but nothing else
    [] -> counter == 1
  }
}
