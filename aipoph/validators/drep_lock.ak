//// This allows many holders of the dao vote token to combine their voting
//// powers by temporarily locking them into a UTxO that can be used on their
//// behalf to vote on dao matters. 

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/token_names
use aipoph/types/drep.{
  DRepDatum, DRepLockRedeemer, LockTokens, Represent, Retire,
}
use assist/addresses
use assist/count
use assist/find
use assist/minting
use assist/payout
use assist/signing

validator(mirror_pid: PolicyId) {
  fn params(
    this_datum: DRepDatum,
    redeemer: DRepLockRedeemer,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) -> {
        // this tx being validated
        let this_tx: Transaction = context.transaction
        // the input being spent
        let this_input: Input =
          find.input_by_ref(this_tx.inputs, output_reference)
        // this address being spent from
        let this_addr: Address = this_input.output.address
        // we need to mint the dao mirror token
        let mint: List<(PolicyId, AssetName, Int)> =
          this_tx.mint
            |> value.from_minted_value()
            |> value.flatten()
        when redeemer is {
          LockTokens -> {
            // that datum must have the correct data structure
            expect that_datum: DRepDatum =
              find.output_datum_by_addr(this_tx.outputs, this_addr)
            //
            // Mint the mirror tokens 1 to 1 with the dao vote token and make
            // sure that the datum doesn't change.
            //
            and {
              // something must be minting or burning
              minting.is_occurring(
                mint,
                mirror_pid,
                token_names.drep_token_name,
              ),
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
              // datums can't change
              this_datum == that_datum,
            }
          }
          Represent -> {
            // this value being spent
            let this_value: Value = this_input.output.value
            // the datum cont must be correct structure
            expect that_datum: DRepDatum =
              find.output_datum_by_addr(this_tx.outputs, this_addr)
            //
            // Nothing can be minting or burning during a represent. The 
            // representative will sign the tx and send the value exactly back
            // to the contract.
            and {
              // nothing can be minting or burning from the mirror pid
              !minting.is_occurring(
                mint,
                mirror_pid,
                token_names.drep_token_name,
              ),
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 1),
              // owner must sign it
              signing.verify_sig(
                this_tx.extra_signatories,
                this_datum.owner.pkh,
              ),
              // must send this value back to this address
              payout.exact(this_addr, this_value, this_tx.outputs),
              // the owner must remain constant
              this_datum == that_datum,
            }
          }
          // A drep wants to retire and stop being a drep
          Retire -> {
            let this_value: Value = this_input.output.value
            // make sure there isnt dao tokens here
            let must_not_hold_drep_tokens: Bool =
              value.quantity_of(
                this_value,
                mirror_pid,
                token_names.drep_token_name,
              ) == 0
            // the drep owner address
            let owner_address: Address = addresses.from_wallet(this_datum.owner)
            and {
              // cant be retiring with someones dao token.
              must_not_hold_drep_tokens,
              // nothing can be minting or burning
              !minting.is_occurring(
                mint,
                mirror_pid,
                token_names.drep_token_name,
              ),
              // single script input
              count.inputs_by_addr(this_tx.inputs, this_addr, 1),
              // zero script output
              count.outputs_by_addr(this_tx.outputs, this_addr, 0),
              // must go back
              payout.exact(owner_address, this_value, this_tx.outputs),
              // owner must sign it
              signing.verify_sig(
                this_tx.extra_signatories,
                this_datum.owner.pkh,
              ),
            }
          }
        }
      }

      // can only spend
      _ -> False
    }
  }
}
