//// this will contain all the code for proving humanity.

use aiken/list
use aiken/transaction.{Input}
use aiken/transaction/credential
use assist/types.{ValidatorHash}

/// This will be the core function for proof of humanity. The inputs
/// should be the datum of the test, the verify redeemer data, and
/// the transaction ValidityRange data. With this information alone
/// this function should output a boolean.
///
/// prove.you_are_a_human()
///
/// TODO
pub fn you_are_a_human(_question: Data, _answer: Data) -> Bool {
  True
}

/// Given a set of validator hashes prove that none of them are being spent. Assume
/// every address is not staked and that the is list is complete.
pub fn not_being_spent_from(
  validator_hashes: List<ValidatorHash>,
  inputs: List<Input>,
) -> Bool {
  when validator_hashes is {
    [vh, ..vhs] -> {
      // check if validator hash exist as an address inside the set of inputs
      let outcome =
        list.any(
          inputs,
          // may be cheaper to do ValidatorHash equality then Address equality?
          // either build up the address or break down the address
          fn(input) { input.output.address == credential.from_script(vh) },
        )
      // if true then not true else continue to the next validator hash
      if outcome {
        !outcome
      } else {
        not_being_spent_from(vhs, inputs)
      }
    }
    // if nothing ever hit then nothing is being spent
    [] -> True
  }
}
