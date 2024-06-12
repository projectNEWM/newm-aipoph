//// This create an output utxo that contains a pointer token and the reference
//// datum. This can only be used once.

use aiken/transaction.{Mint, OutputReference, ScriptContext, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId}
use aipoph/keys
use aipoph/query
use aipoph/token_names
use aipoph/types/reference.{Contracts, ReferenceDatum}
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
    // must be minting
    expect Mint(currency_symbol) = context.purpose
    // destruct the tx with required fields
    let Transaction { inputs, outputs, mint, .. } = context.transaction
    // we need to mint the pointer token
    let mint_list: List<(PolicyId, AssetName, Int)> =
      mint
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
    // that datum must have the ReferenceDatum data structure, and it must
    // exist on an output that has a the pointer token.
    expect that_datum: ReferenceDatum =
      find.output_datum_by_nft(outputs, currency_symbol, token_name)
    // get the contract data from that datum
    expect contract_data: Contracts =
      reference.find_data(that_datum, keys.contracts)
    // the reference hash must exist inside of that datum
    let ref_data_hash: ValidatorHash =
      reference.find_contract(contract_data, keys.reference_contract)
    // build the reference address, no staking
    let ref_data_addr: Address = credential.from_script(ref_data_hash)
    //
    // Check if the intial conditions exist, prove that the txid is actually
    // being spent, and mint exactly one pointer onto the reference address.
    //
    and {
      // petition must exist and be positive
      query.does_the_intial_state_exist(ref_data_addr, that_datum)?,
      // these inputs must be spending this output reference
      tx.is_spending_input(inputs, this_out_ref)?,
      // mint exactly 1 pointer token
      minting.exact(mint_list, currency_symbol, token_name, 1)?,
      // must send the reference address at least the pointer token
      payout.at_least(
        ref_data_addr,
        value.from_asset(currency_symbol, token_name, 1),
        outputs,
      )?,
    }
  }
}
