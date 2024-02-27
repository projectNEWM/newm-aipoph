#!/bin/bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json

# oracle script
poh_lock_script_path="../../contracts/poh_lock_contract.plutus"
poh_lock_script_address=$(${cli} address build --payment-script-file ${poh_lock_script_path} ${network})

# dao script
dao_script_path="../../contracts/dao_contract.plutus"
dao_script_address=$(${cli} address build --payment-script-file ${dao_script_path} ${network})

# oracle script
oracle_script_path="../../contracts/oracle_contract.plutus"
oracle_script_address=$(${cli} address build --payment-script-file ${oracle_script_path} ${network})

# collat
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# user
user_address=$(cat ../wallets/user-wallet/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/user-wallet/payment.vkey)

# voter
voter_address=$(cat ../wallets/voter-wallet/payment.addr)
voter_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/voter-wallet/payment.vkey)

poh_policy_id=$(cardano-cli transaction policyid --script-file ../../contracts/poh_mint_contract.plutus)

tx_id_hash=$(jq -r '.tx_id_hash' ../../start_info.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../../start_info.json)
pointer_prefix="5f6169706f70685f"
pointer_pid=$(cat ../../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

# asset to trade
# the locking token information

# incentive, deposit, and poh token
min_utxo=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/oracle/worst-case-oracle-datum.json \
    --tx-out="${oracle_script_address} + 5000000" | tr -dc '0-9')

oracle_script_out="${oracle_script_address} + ${min_utxo}"

poh_token="1 ${poh_policy_id}.426567696e205468652050726f6f66204f662048756d616e6974792054657374"

worst_case_tokens="9223372036854775807 632e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162b.632e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162b00000000
+ 9223372036854775807 532e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c.532e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c00000000
+ 9223372036854775807 432e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162d.432e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c00000000"
min_utxo=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/poh/worst-case-poh-datum.json \
    --tx-out="${poh_lock_script_address} + 5000000 + ${worst_case_tokens}" | tr -dc '0-9')

# 3 ada for fees and 2 ada for the min utxo for the coh
# take incentive out, take 1 fee out
required_lovelace=$((${min_utxo} + 3000000 + 2000000 - 1000000))
poh_lock_script_out="${poh_lock_script_address} + ${required_lovelace} + ${poh_token}"
echo "Oracle OUTPUT: "${oracle_script_out}
echo "PoH OUTPUT: "${poh_lock_script_out}
#
# exit
#

echo -e "\033[0;36m Gathering Voter UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${voter_address} \
    --out-file ../tmp/voter_utxo.json

TXNS=$(jq length ../tmp/voter_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${voter_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/voter_utxo.json)
voter_tx_in=${TXIN::-8}
voter_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/voter_utxo.json)

# voter tokens needs to be dynamic
voter_out="${voter_address} + $((${voter_lovelace_value} + 1000000)) + 153456789 015d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d.43757272656e6379"
echo "Voter OUTPUT: "${voter_out}


# get script utxo
echo -e "\033[0;36m Gathering DAO UTxO Information  \033[0m"
${cli} query utxo \
    --address ${dao_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${dao_script_address} \033[0m \n";
.   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" --arg policy_id "$pointer_pid" --arg token_name "$pointer_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
dao_tx_in=${TXIN::-8}

# get script utxo
echo -e "\033[0;36m Gathering PoH UTxO Information  \033[0m"
${cli} query utxo \
    --address ${poh_lock_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${poh_lock_script_address} \033[0m \n";
.   exit;
fi
poh_lock_tx_in=$(jq -r 'keys[0]' ../tmp/script_utxo.json)

# get script utxo
echo -e "\033[0;36m Gathering Oracle UTxO Information  \033[0m"
${cli} query utxo \
    --address ${oracle_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${oracle_script_address} \033[0m \n";
.   exit;
fi
oracle_tx_in=$(jq -r 'keys[0]' ../tmp/script_utxo.json)

# collat info
echo -e "\033[0;36m Gathering Collateral UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${collat_address} \
    --out-file ../tmp/collat_utxo.json

TXNS=$(jq length ../tmp/collat_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${collat_address} \033[0m \n";
   exit;
fi
collat_tx_in=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)

# script reference utxo

cpu_steps=0
mem_steps=0

sale_execution_unts="(${cpu_steps}, ${mem_steps})"

# we need to update the oracle datum and the poh datum

rand_num=$(python3 -c "import sys; sys.path.append('../py/'); from randomness import number; number()")
rand_str=$(python3 -c "import sys; sys.path.append('../py/'); from randomness import string; string()")

cur_rand_num=$(jq -r '.fields[0].int' ../data/oracle/oracle-datum.json)
echo Seed For Graph: ${cur_rand_num}
cur_rand_str=$(jq -r '.fields[1].bytes' ../data/oracle/oracle-datum.json)

#   A five (5) minute window would be 5 * 60 * 1000  = 300,000.
# set the time for the test
cur_time=$(echo `expr $(echo $(date +%s%3N)) + $(echo 0)`)
new_time=$(echo `expr $(echo $(date +%s%3N)) + $(echo 300000)`)

graph=$(python3 -c "import sys; sys.path.append('../py/'); from randomness import number; number()")

edges=$(../py/k-coloring-test/venv/bin/python -c "
import sys; sys.path.append('../py/k-coloring-test');
from src.generate import generate;
from src.convert import to_datum;
g = generate(10, 12, ${cur_rand_num});
print(to_datum(g))
")

variable=${edges}; jq --argjson variable "$variable" '.fields[4].fields[2].fields[0].list=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json

../py/k-coloring-test/venv/bin/python -c "import sys; sys.path.append('../py/k-coloring-test');from src.generate import generate; from src.coloring import find_minimal_coloring; c = find_minimal_coloring(generate(10, 12, ${cur_rand_num}));print(list(c.values()))"

# exit

# update the random number
variable=${rand_num}; jq --argjson variable "$variable" '.fields[0].int=$variable' ../data/oracle/updated-oracle-datum.json > ../data/oracle/updated-oracle-datum-new.json
mv ../data/oracle/updated-oracle-datum-new.json ../data/oracle/updated-oracle-datum.json
# update the random string
variable=${rand_str}; jq --arg variable "$variable" '.fields[1].bytes=$variable' ../data/oracle/updated-oracle-datum.json > ../data/oracle/updated-oracle-datum-new.json
mv ../data/oracle/updated-oracle-datum-new.json ../data/oracle/updated-oracle-datum.json

variable=${cur_time}; jq --argjson variable "$variable" '.fields[4].fields[0].fields[0].int=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json
variable=${new_time}; jq --argjson variable "$variable" '.fields[4].fields[0].fields[1].int=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json

variable=${cur_rand_num}; jq --argjson variable "$variable" '.fields[4].fields[1].fields[0].int=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json
variable=${cur_rand_str}; jq --arg variable "$variable" '.fields[4].fields[1].fields[1].bytes=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json

poh_lock_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-poh_lock_contract.plutus.signed )
poh_mint_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-poh_mint_contract.plutus.signed)
oracle_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-oracle_contract.plutus.signed )

echo -e "\033[0;36m Building Tx \033[0m"
${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --read-only-tx-in-reference ${dao_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${poh_lock_tx_in} \
    --spending-tx-in-reference="${poh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${sale_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/poh/start-test-redeemer.json \
    --tx-out="${poh_lock_script_out}" \
    --tx-out-inline-datum-file ../data/poh/updated-poh-datum.json \
    --tx-in ${oracle_tx_in} \
    --spending-tx-in-reference="${oracle_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${sale_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/oracle/oracle-redeemer.json \
    --tx-out="${oracle_script_out}" \
    --tx-out-inline-datum-file ../data/oracle/updated-oracle-datum.json \
    --tx-in ${voter_tx_in} \
    --tx-out="${voter_out}" \
    --required-signer-hash ${user_pkh} \
    --required-signer-hash ${voter_pkh} \
    --required-signer-hash ${collat_pkh} \
    --mint="${poh_token}" \
    --mint-tx-in-reference="${poh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${poh_policy_id}" \
    --mint-reference-tx-in-execution-units="${sale_execution_unts}" \
    --mint-reference-tx-in-redeemer-file ../data/poh/mint-redeemer.json \
    --fee 0

python3 -c "import sys, json; sys.path.append('../py/'); from tx_simulation import from_file; exe_units=from_file('../tmp/tx.draft', False, debug=False);print(json.dumps(exe_units))" > ../data/poh/exe_units.json

cat ../data/poh/exe_units.json
echo poh lock ${poh_lock_tx_in}
echo oracle ${oracle_tx_in}

# exit

plcpu=$(jq -r '.[0].cpu' ../data/poh/exe_units.json)
plmem=$(jq -r '.[0].mem' ../data/poh/exe_units.json)

ocpu=$(jq -r '.[1].cpu' ../data/poh/exe_units.json)
omem=$(jq -r '.[1].mem' ../data/poh/exe_units.json)

pmcpu=$(jq -r '.[2].cpu' ../data/poh/exe_units.json)
pmmem=$(jq -r '.[2].mem' ../data/poh/exe_units.json)


poh_lock_execution_unts="(${plcpu}, ${plmem})"
oracle_execution_unts="(${ocpu}, ${omem})"
poh_mint_execution_unts="(${pmcpu}, ${pmmem})"


FEE=$(${cli} transaction calculate-min-fee --tx-body-file ../tmp/tx.draft ${network} --protocol-params-file ../tmp/protocol.json --tx-in-count 3 --tx-out-count 3 --witness-count 3)
fee=$(echo $FEE | rev | cut -c 9- | rev)

pl_computation_fee=$(echo "0.0000721*${plcpu} + 0.0577*${plmem}" | bc)
o_computation_fee=$(echo "0.0000721*${ocpu} + 0.0577*${omem}" | bc)
pm_computation_fee=$(echo "0.0000721*${pmcpu} + 0.0577*${pmmem}" | bc)

pl_computation_fee_int=$(printf "%.0f" "$pl_computation_fee")
o_computation_fee_int=$(printf "%.0f" "$o_computation_fee")
pm_computation_fee_int=$(printf "%.0f" "$pm_computation_fee")

total_fee=$((${fee} + ${pl_computation_fee_int} + ${o_computation_fee_int} + ${pm_computation_fee_int}))
echo FEE: $total_fee
required_lovelace=$((${min_utxo} + 3000000 + 2000000 - 1000000 - ${total_fee}))
poh_lock_script_out="${poh_lock_script_address} + ${required_lovelace} + ${poh_token}"
echo "Proof of Humanity OUTPUT: "${poh_lock_script_out}


${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --read-only-tx-in-reference ${dao_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${poh_lock_tx_in} \
    --spending-tx-in-reference="${poh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${poh_lock_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/poh/start-test-redeemer.json \
    --tx-out="${poh_lock_script_out}" \
    --tx-out-inline-datum-file ../data/poh/updated-poh-datum.json \
    --tx-in ${oracle_tx_in} \
    --spending-tx-in-reference="${oracle_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${oracle_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/oracle/oracle-redeemer.json \
    --tx-out="${oracle_script_out}" \
    --tx-out-inline-datum-file ../data/oracle/updated-oracle-datum.json \
    --tx-in ${voter_tx_in} \
    --tx-out="${voter_out}" \
    --required-signer-hash ${user_pkh} \
    --required-signer-hash ${voter_pkh} \
    --required-signer-hash ${collat_pkh} \
    --mint="${poh_token}" \
    --mint-tx-in-reference="${poh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${poh_policy_id}" \
    --mint-reference-tx-in-execution-units="${poh_mint_execution_unts}" \
    --mint-reference-tx-in-redeemer-file ../data/poh/mint-redeemer.json \
    --fee ${total_fee}


#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../wallets/user-wallet/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
    --signing-key-file ../wallets/voter-wallet/payment.skey \
    --tx-body-file ../tmp/tx.draft \
    --out-file ../tmp/tx.signed \
    ${network}
#
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} transaction submit \
    ${network} \
    --tx-file ../tmp/tx.signed

tx=$(cardano-cli transaction txid --tx-file ../tmp/tx.signed)
echo "Tx Hash:" $tx

cp ../data/poh/updated-poh-datum.json ../data/poh/poh-datum.json
cp ../data/oracle/updated-oracle-datum.json ../data/oracle/oracle-datum.json