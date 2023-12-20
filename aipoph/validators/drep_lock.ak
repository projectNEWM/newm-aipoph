use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/types
use aipoph/types/drep.{DRepDatum, DRepLockRedeemer, LockTokens, Voting}
use assist/count
use assist/find
use assist/minting
use assist/payout
use assist/signing

validator(mirror_pid: ByteArray) {
  fn params(
    this_datum: DRepDatum,
    redeemer: DRepLockRedeemer,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // tx being validated
        let tx: Transaction = context.transaction
        let this_input: Input = find.input_by_ref(tx.inputs, output_reference)
        let this_addr: Address = this_input.output.address
        when redeemer is {
          // the majority of the validation logic is in the minting contract
          // make sure we spend one thing and a mint occurs
          LockTokens -> {
            let mint: List<(PolicyId, AssetName, Int)> =
              tx.mint
                |> value.from_minted_value()
                |> value.flatten()
            and {
              minting.is_occurring(mint, mirror_pid, types.drep_token_name),
              // single script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
            }
          }
          // this is just a simple spend that continues the drep back to itself.
          Voting -> {
            let this_value: Value = this_input.output.value
            // the datum cont must be correct structure
            expect that_datum: DRepDatum =
              find.output_datum_by_addr(tx.outputs, this_addr)
            and {
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
        }
      }
      // can only spend
      _ -> False
    }
  }
}
