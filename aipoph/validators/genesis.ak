//// This create an output utxo that contains a dao pointer token and the dao
//// datum and it only can be used once.

use aiken/transaction.{Mint, OutputReference, ScriptContext, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId}
use aipoph/keys
use aipoph/reference
use aipoph/token_names
use aipoph/types/dao.{Contracts, DAODatum}
use assist/find
use assist/minting
use assist/payout
use assist/std
use assist/tx
use assist/types/hashes.{TxHash, ValidatorHash}
use assist/values

validator(
  // transaction id hash
  tx_id_hash: TxHash,
  // transaction id index
  tx_id_idx: Int,
) {
  fn params(_redeemer: Void, context: ScriptContext) -> Bool {
    when context.purpose is {
      Mint(currency_symbol) -> {
        // the transaction being validated
        let this_tx: Transaction = context.transaction
        // we need to mint the dao pointer token
        let mint: List<(PolicyId, AssetName, Int)> =
          this_tx.mint
            |> value.from_minted_value()
            |> value.flatten()
        // generate the name from the compiled data
        let token_name: AssetName =
          values.unique_token_name(
            tx_id_hash,
            tx_id_idx,
            // _aipoph_
            token_names.pointer_prefix,
          )
        // this output reference must be spent
        let this_out_ref: OutputReference = std.out_ref(tx_id_hash, tx_id_idx)
        // that datum must have the DAODatum data structure, and it must
        // exist on an output that has a the pointer token.
        expect that_datum: DAODatum =
          find.output_datum_by_nft(this_tx.outputs, currency_symbol, token_name)
        // get the contract data from that datum
        expect contract_data: Contracts =
          dao.find_data(that_datum, keys.contracts)
        // the dao hash must exist inside of that datum
        let dao_hash: ValidatorHash =
          dao.find_contract(contract_data, keys.dao_contract)
        // build the dao address, no staking
        let dao_addr: Address = credential.from_script(dao_hash)
        //
        // check if the intial conditions exist, prove that the txid is actually
        // being spent, and mint exactly one pointer onto the dao address.
        //
        and {
          // petition must exist and be positive
          reference.does_the_intial_state_exist(dao_addr, that_datum),
          // these inputs must be spending this output reference
          tx.is_spending_input(this_tx.inputs, this_out_ref),
          // mint exactly 1 pointer token
          minting.exact(mint, currency_symbol, token_name, 1),
          // must send the dao address at least the pointer token
          payout.at_least(
            dao_addr,
            value.from_asset(currency_symbol, token_name, 1),
            this_tx.outputs,
          ),
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
