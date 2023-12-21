//// this controls the locking of the poh pointer token and contains all of the
//// poh test logic. a successful test will issue a certificate of humanity

use aiken/interval
use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/prove
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
use assist/values

validator(poh_pid: PolicyId, coh_pid: PolicyId) {
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
        // // get reference utxo
        // expect dao_hash: ValidatorHash = dao_hash_data
        // let dao_addr: Address = credential.from_script(dao_hash)
        // let dao_input: Input = find.input_by_addr(tx.reference_inputs, dao_addr)
        // // check if the ref input has the correct starter token
        // let pointer_token_check: Bool =
        //   values.prove_exact_nft(
        //     pointer_pid,
        //     pointer_tkn,
        //     dao_input.output.value,
        //   )
        // // get the reference datum
        // expect dao_datum: DAODatum = data.input_datum(dao_input)
        // // this will fail if it doesn't exist
        // expect threshold_data: Thresholds =
        //   dao.find_data(dao_datum, keys.thresholds)
        // // the threshold to change data
        // // this will fail if it doesn't exist
        // let start_poh_test_threshold: Int =
        //   dao.find_threshold(threshold_data, keys.start_poh_test_threshold)
        // // how much they have inside the tx
        // let enough_for_threshold: Bool =
        //   values.total_token_amount(tx.inputs, dao_pid, dao_tkn, 0) >= start_poh_test_threshold
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
              minting.is_occurring(mint, poh_pid, types.poh_token_name),
              // single script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
              // datums must change a specific way
              poh.start_test_datum_validation(this_datum, that_datum),
            }
          }
          // this will end the test and mint a stage 0 coh token
          EndTest { proof } -> {
            let this_value: Value = this_input.output.value
            // the datum cont must be correct structure
            expect that_datum: PoHDatum =
              find.output_datum_by_addr(tx.outputs, this_addr)
            and {
              // must have poh token
              values.prove_exact_nft(poh_pid, types.poh_token_name, this_value),
              // something is being minted  and burned
              minting.is_occurring(mint, coh_pid, types.coh_token_name),
              // single script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
              // owner must sign it
              signing.verify_sig(tx.extra_signatories, this_datum.owner.pkh),
              // must go back
              payout.exact(this_addr, this_value, tx.outputs),
              // datums must change a specific way
              poh.end_test_datum_validation(this_datum, that_datum, proof),
              // test must still be valid
              poh.valid_test_entry(
                this_datum.test_data.validity_range,
                tx.validity_range,
              ),
              // prove you are a human
              prove.you_are_a_human(this_datum.test_data.question, proof.answer),
            }
          }
          // this will perform additional logic that can advance a test, The datum must contain the proof
          Advance -> {
            let this_value: Value = this_input.output.value
            and {
              // something is being minted  and burned
              !minting.is_occurring(mint, poh_pid, types.poh_token_name),
              // something is being minted  and burned
              !minting.is_occurring(mint, coh_pid, types.coh_token_name),
              // must go back
              payout.exact(this_addr, this_value, tx.outputs),
              // single script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
              // the test is over
              interval.is_entirely_before(
                tx.validity_range,
                this_datum.test_data.validity_range.start,
              ) == True,
              // prove you are a human
              prove.you_are_a_human(
                this_datum.test_data.question,
                this_datum.test_data.answer,
              ),
            }
          }

          // withdraws a deposit from a failed test
          Withdraw -> True
          // this quits if the test hasnt started or the user ends teh test successfully
          Quit -> {
            let this_value: Value = this_input.output.value
            // make sure there isnt dao tokens here
            let empty_drep_check: Bool =
              value.quantity_of(this_value, poh_pid, types.poh_token_name) == 0
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
              minting.is_occurring(mint, poh_pid, types.poh_token_name),
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
