#!/usr/bin/env bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json

# poh script
poh_lock_script_path="../../contracts/poh_lock_contract.plutus"
poh_lock_script_address=$(${cli} address build --payment-script-file ${poh_lock_script_path} ${network})

# coh script
coh_lock_script_path="../../contracts/coh_lock_contract.plutus"
coh_lock_script_address=$(${cli} address build --payment-script-file ${coh_lock_script_path} ${network})

# reference script
reference_script_path="../../contracts/reference_contract.plutus"
reference_script_address=$(${cli} address build --payment-script-file ${reference_script_path} ${network})

# collat
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# user
user_address=$(cat ../wallets/user-wallet/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/user-wallet/payment.vkey)

# voter
voter_address=$(cat ../wallets/voter-wallet/payment.addr)
voter_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/voter-wallet/payment.vkey)

# poh token
poh_policy_id=$(cardano-cli transaction policyid --script-file ../../contracts/poh_mint_contract.plutus)
poh_token_name=$(jq -r '.poh_token_name' ../../config.json)
poh_token="-1 ${poh_policy_id}.${poh_token_name}"

# coh token information
coh_policy_id=$(cardano-cli transaction policyid --script-file ../../contracts/coh_mint_contract.plutus)
coh_token_name=$(jq -r '.coh_token_name' ../../config.json)
coh_token="1 ${coh_policy_id}.${coh_token_name}"

# genesis token information
tx_id_hash=$(jq -r '.tx_id_hash' ../../config.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../../config.json)
pointer_prefix=$(jq -r '.pointer_prefix' ../../config.json)
pointer_pid=$(cat ../../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

# happy path assumes 1 ADA as incentive
incentive_amt=1000000

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

echo "PoH Lock UTxO:" $poh_lock_tx_in
string=${poh_lock_tx_in}
IFS='#' read -ra array <<< "$string"

callable="ca11ab1e"
coh_pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${array[0]}', ${array[1]}, '${callable}')")
coh_pointer_token="1 ${coh_policy_id}.${coh_pointer_tkn}"
echo -n ${coh_pointer_tkn} > ../data/coh/coh-token.name

coh_min_lovelace=$(jq -r '.fields[3].int' ../data/poh/poh-datum.json)
mint_token="${coh_token} + ${coh_pointer_token}"

required_lovelace=$(jq -r 'to_entries[].value.value.lovelace' ../tmp/script_utxo.json)
owner_script_out="${user_address} + $((${required_lovelace} - ${incentive_amt} - ${coh_min_lovelace}))"
coh_lock_script_out="${coh_lock_script_address} + ${coh_min_lovelace} + ${coh_token} + ${coh_pointer_token}"
echo "Owner OUTPUT: "${owner_script_out}
echo "Certificate of Humanity OUTPUT: "${coh_lock_script_out}
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

# voter sends teh action token back and gets the incentive token
action_pid=$(jq -r '.action_pid' ../../config.json)
action_tkn=$(jq -r '.action_tkn' ../../config.json)
action_amt=$(jq -r --arg action_pid "$action_pid" --arg action_tkn "$action_tkn" '.[].value[$action_pid][$action_tkn]' ../tmp/voter_utxo.json)

voter_out="${voter_address} + $((${voter_lovelace_value} + ${incentive_amt})) + ${action_amt} ${action_pid}.${action_tkn}"
echo "Voter OUTPUT: "${voter_out}


# get reference script utxo
echo -e "\033[0;36m Gathering Reference UTxO Information  \033[0m"
${cli} query utxo \
    --address ${reference_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${reference_script_address} \033[0m \n";
.   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" --arg policy_id "$pointer_pid" --arg token_name "$pointer_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
reference_tx_in=${TXIN::-8}

# get poh script utxo
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

# check if the test is still ongoing
test_end_time=$(jq -r '.[].inlineDatum.fields[4].fields[0].fields[1].int' ../tmp/script_utxo.json)
cur_time=$(echo `expr $(echo $(date +%s%3N))`)

if [ "$cur_time" -le "$test_end_time" ]; then
  echo "Test Is Live!"
  time_diff_ms=$((test_end_time - cur_time))
  time_diff_min=$((time_diff_ms / 60000))
  echo "There are $time_diff_min minutes left in the test."
  exit 1
else
  echo "Test Is Over!"
fi

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

# script reference utxo

poh_lock_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-poh_lock_contract.plutus.signed )
poh_mint_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-poh_mint_contract.plutus.signed)
coh_mint_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-coh_mint_contract.plutus.signed)

slot=$(${cli} query tip ${network} | jq .slot)
current_slot=$(($slot - 1))
final_slot=$(($slot + 750))


echo Validity Range:
echo $current_slot "<->" $final_slot

# asset to trade
cur_rand_num=$(jq -r '.fields[4].fields[1].fields[0].int' ../data/poh/poh-datum.json)
edges=$(../py/k-coloring-test/venv/bin/python -c "
import sys; sys.path.append('../py/k-coloring-test');
from src.generate import generate;
from src.convert import graph_to_datum;
g = generate(10, 12, ${cur_rand_num});
print(graph_to_datum(g))
")
variable=${edges}; jq --argjson variable "$variable" '.fields[1].fields[0].fields[0].list=$variable' ../data/coh/coh-datum.json | sponge ../data/coh/coh-datum.json

coloring=$(../py/k-coloring-test/venv/bin/python -c "
import sys;
sys.path.append('../py/k-coloring-test');
from src.generate import generate;
from src.coloring import find_minimal_coloring;
from src.convert import coloring_to_datum;
g = generate(10, 12, ${cur_rand_num});
c = find_minimal_coloring(g);
print(coloring_to_datum(list(c.values())))")

variable=${coloring}; jq --argjson variable "$variable" '.fields[1].fields[1].fields[0].list=$variable' ../data/coh/coh-datum.json | sponge ../data/coh/coh-datum.json

graph_hash=$(../py/k-coloring-test/venv/bin/python -c "
import sys;
sys.path.append('../py/k-coloring-test');
from src.generate import generate;
from src.convert import graph_to_hash;
g = generate(10, 12, ${cur_rand_num});
print(graph_to_hash(g));
")

color_hash=$(../py/k-coloring-test/venv/bin/python -c "
import sys;
sys.path.append('../py/k-coloring-test');
from src.generate import generate;
from src.convert import coloring_to_hash;
from src.coloring import find_minimal_coloring;
g = generate(10, 12, ${cur_rand_num});
c = list(find_minimal_coloring(g).values());
print(coloring_to_hash(c));
")

graph_sig=$(python -c "
import sys;
sys.path.append('../py/data-signing');
from signature import sign;
skey_path = '../wallets/user-wallet/signing.skey';
signature = sign(skey_path, '${graph_hash}');
print(signature)
")

pkh=$(cat ../wallets/user-wallet/signing.vkey)
echo Graph Pkh: $pkh
variable=${pkh}; jq --arg variable "$variable" '.fields[1].fields[1].fields[1].fields[0].bytes=$variable' ../data/coh/coh-datum.json | sponge ../data/coh/coh-datum.json

echo Graph Hash: $graph_hash
variable=${graph_hash}; jq --arg variable "$variable" '.fields[1].fields[1].fields[1].fields[1].bytes=$variable' ../data/coh/coh-datum.json | sponge ../data/coh/coh-datum.json

echo Graph Sig: $graph_sig
variable=${graph_sig}; jq --arg variable "$variable" '.fields[1].fields[1].fields[1].fields[2].bytes=$variable' ../data/coh/coh-datum.json | sponge ../data/coh/coh-datum.json

color_sig=$(python -c "
import sys;
sys.path.append('../py/data-signing');
from signature import sign;
skey_path = '../wallets/website-wallet/payment.skey';
signature = sign(skey_path, '${color_hash}');
print(signature)
")

pkh=$(cat ../wallets/website-wallet/payment.vkey)
echo Color Pkh: $pkh
variable=${pkh}; jq --arg variable "$variable" '.fields[1].fields[1].fields[2].fields[0].bytes=$variable' ../data/coh/coh-datum.json | sponge ../data/coh/coh-datum.json

echo Color Hash: $color_hash
variable=${color_hash}; jq --arg variable "$variable" '.fields[1].fields[1].fields[2].fields[1].bytes=$variable' ../data/coh/coh-datum.json | sponge ../data/coh/coh-datum.json

echo Color Sig: $color_sig
variable=${color_sig}; jq --arg variable "$variable" '.fields[1].fields[1].fields[2].fields[2].bytes=$variable' ../data/coh/coh-datum.json | sponge ../data/coh/coh-datum.json


variable=${coh_policy_id}; jq --arg variable "$variable" '.fields[1].fields[2].fields[0].bytes=$variable' ../data/coh/coh-datum.json | sponge ../data/coh/coh-datum.json
variable=${coh_pointer_tkn}; jq --arg variable "$variable" '.fields[1].fields[2].fields[1].bytes=$variable' ../data/coh/coh-datum.json | sponge ../data/coh/coh-datum.json

echo -e "\033[0;36m Building Tx \033[0m"
${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --invalid-before ${current_slot} \
    --invalid-hereafter ${final_slot} \
    --read-only-tx-in-reference ${reference_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${poh_lock_tx_in} \
    --spending-tx-in-reference="${poh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${sale_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/poh/verify-test-redeemer.json \
    --tx-out="${owner_script_out}" \
    --tx-out="${coh_lock_script_out}" \
    --tx-out-inline-datum-file ../data/coh/coh-datum.json \
    --tx-in ${voter_tx_in} \
    --tx-out="${voter_out}" \
    --required-signer-hash ${user_pkh} \
    --required-signer-hash ${voter_pkh} \
    --required-signer-hash ${collat_pkh} \
    --mint="${poh_token} + ${mint_token}" \
    --mint-tx-in-reference="${poh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${poh_policy_id}" \
    --mint-reference-tx-in-execution-units="${sale_execution_unts}" \
    --mint-reference-tx-in-redeemer-file ../data/poh/burn-redeemer.json \
    --mint-tx-in-reference="${coh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${coh_policy_id}" \
    --mint-reference-tx-in-execution-units="${sale_execution_unts}" \
    --mint-reference-tx-in-redeemer-file ../data/coh/mint-redeemer.json \
    --fee 0

python3 -c "import sys, json; sys.path.append('../py/'); from tx_simulation import from_file; exe_units=from_file('../tmp/tx.draft', False, debug=False);print(json.dumps(exe_units))" > ../data/poh/exe_units.json

cat ../data/poh/exe_units.json

# echo ${poh_lock_tx_in}
# echo ${poh_policy_id}
# echo ${coh_policy_id}

o_index=$(python3 -c "import sys; sys.path.append('../py/'); from lexico_order import compare_strings; x = compare_strings('${poh_policy_id}', '${coh_policy_id}'); print(x)")
poh_index=$((1 + ${o_index}))
coh_index=$((2 - ${o_index}))

# exit

plcpu=$(jq -r '.[0].cpu' ../data/poh/exe_units.json)
plmem=$(jq -r '.[0].mem' ../data/poh/exe_units.json)

pohcpu=$(jq -r --argjson index "$poh_index" '.[$index].cpu' ../data/poh/exe_units.json)
pohmem=$(jq -r --argjson index "$poh_index" '.[$index].mem' ../data/poh/exe_units.json)

cohcpu=$(jq -r --argjson index "$coh_index" '.[$index].cpu' ../data/poh/exe_units.json)
cohmem=$(jq -r --argjson index "$coh_index" '.[$index].mem' ../data/poh/exe_units.json)


poh_lock_execution_units="(${plcpu}, ${plmem})"
poh_mint_execution_units="(${pohcpu}, ${pohmem})"
coh_mint_execution_units="(${cohcpu}, ${cohmem})"


FEE=$(${cli} transaction calculate-min-fee --tx-body-file ../tmp/tx.draft ${network} --protocol-params-file ../tmp/protocol.json --tx-in-count 3 --tx-out-count 3 --witness-count 3)
fee=$(echo $FEE | rev | cut -c 9- | rev)

pl_computation_fee=$(echo "0.0000721*${plcpu} + 0.0577*${plmem}" | bc)
poh_computation_fee=$(echo "0.0000721*${pohcpu} + 0.0577*${pohmem}" | bc)
coh_computation_fee=$(echo "0.0000721*${cohcpu} + 0.0577*${cohmem}" | bc)

pl_computation_fee_int=$(printf "%.0f" "$pl_computation_fee")
poh_computation_fee_int=$(printf "%.0f" "$poh_computation_fee")
coh_computation_fee_int=$(printf "%.0f" "$coh_computation_fee")

total_fee=$((${fee} + ${pl_computation_fee_int} + ${poh_computation_fee_int} + ${coh_computation_fee_int}))
echo FEE: $total_fee
owner_script_out="${user_address} + $((${required_lovelace} - ${incentive_amt} - ${coh_min_lovelace} - ${total_fee}))"

${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --invalid-before ${current_slot} \
    --invalid-hereafter ${final_slot} \
    --read-only-tx-in-reference ${reference_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${poh_lock_tx_in} \
    --spending-tx-in-reference="${poh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${poh_lock_execution_units}" \
    --spending-reference-tx-in-redeemer-file ../data/poh/verify-test-redeemer.json \
    --tx-out="${owner_script_out}" \
    --tx-out="${coh_lock_script_out}" \
    --tx-out-inline-datum-file ../data/coh/coh-datum.json \
    --tx-in ${voter_tx_in} \
    --tx-out="${voter_out}" \
    --required-signer-hash ${user_pkh} \
    --required-signer-hash ${voter_pkh} \
    --required-signer-hash ${collat_pkh} \
    --mint="${poh_token} + ${mint_token}" \
    --mint-tx-in-reference="${poh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${poh_policy_id}" \
    --mint-reference-tx-in-execution-units="${poh_mint_execution_units}" \
    --mint-reference-tx-in-redeemer-file ../data/poh/burn-redeemer.json \
    --mint-tx-in-reference="${coh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${coh_policy_id}" \
    --mint-reference-tx-in-execution-units="${coh_mint_execution_units}" \
    --mint-reference-tx-in-redeemer-file ../data/coh/mint-redeemer.json \
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
