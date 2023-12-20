//// this controls the locking of the poh pointer token and contains all of the
//// poh test logic. a successful test will issue a certificate of humanity

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/types
use aipoph/types/poh.{
  Advance, EndTest, PoHDatum, PoHRedeemer, Quit, StartTest, Withdraw,
}
use assist/addresses
use assist/count
use assist/find
use assist/minting
use assist/payout
use assist/signing

// use aipoph/prove

validator(mirror_pid: PolicyId) {
  fn params(
    this_datum: PoHDatum,
    redeemer: PoHRedeemer,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // tx being validated
        let tx: Transaction = context.transaction
        let this_input: Input = find.input_by_ref(tx.inputs, output_reference)
        let this_addr: Address = this_input.output.address
        // something will be burned 
        let mint: List<(PolicyId, AssetName, Int)> =
          tx.mint
            |> value.from_minted_value()
            |> value.flatten()
        when redeemer is {
          // this starts the poh test
          StartTest -> {
            // the datum cont must be correct structure
            expect that_datum: PoHDatum =
              find.output_datum_by_addr(tx.outputs, this_addr)
            and {
              // something is being minted
              minting.is_occurring(mint, mirror_pid, types.poh_token_name),
              // single script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
              // datums can't change
              this_datum == that_datum,
            }
          }
          // this will end the test and mint a stage 0 coh token
          EndTest { proof } -> {
            let this_value: Value = this_input.output.value
            // the datum cont must be correct structure
            expect that_datum: PoHDatum =
              find.output_datum_by_addr(tx.outputs, this_addr)
            and {
              // something is being minted  and burned
              minting.is_occurring(mint, mirror_pid, types.poh_token_name),
              // single script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
              // owner must sign it
              signing.verify_sig(tx.extra_signatories, this_datum.owner.pkh),
              // must go back
              payout.exact(this_addr, this_value, tx.outputs),
              // datums can't change
              this_datum == that_datum,
            }
          }
          // this will perform additional logic that can advance a test
          Advance -> True
          // withdraws a deposit from a failed test
          Withdraw -> True
          // this quits if the test hasnt started or the user ends teh test successfully
          Quit -> {
            let this_value: Value = this_input.output.value
            // make sure there isnt dao tokens here
            let empty_drep_check: Bool =
              value.quantity_of(this_value, mirror_pid, types.poh_token_name) == 0
            // the drep owner address
            let owner_address: Address =
              addresses.create_address(
                this_datum.owner.pkh,
                this_datum.owner.sc,
              )
            and {
              // cant be retiring with someones dao token.
              empty_drep_check,
              // something is being burned
              minting.is_occurring(mint, mirror_pid, types.poh_token_name),
              // single script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // zero script output
              count.outputs_by_addr(tx.outputs, this_addr, 0),
              // must go back
              payout.exact(owner_address, this_value, tx.outputs),
              // owner must sign it
              signing.verify_sig(tx.extra_signatories, this_datum.owner.pkh),
            }
          }
        }
      }

      // can only spend
      _ -> False
    }
  }
}
