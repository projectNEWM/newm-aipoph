#!/bin/bash
set -e

# create directories if dont exist
mkdir -p contracts
mkdir -p hashes

# remove old files
rm contracts/* || true
rm hashes/* || true

# build out the entire script
echo -e "\033[1;34m Building Contracts \033[0m"
aiken build
# aiken build --keep-traces

# the locking token information
tx_id_hash=$(jq -r '.tx_id_hash' start_info.json)
tx_id_idx=$(jq -r '.tx_id_idx' start_info.json)
# one liner for correct cbor
# requires cbor2
tx_id_hash_cbor=$(python3 -c "import cbor2;hex_string='${tx_id_hash}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")
tx_id_idx_cbor=$(python3 -c "import cbor2;encoded=cbor2.dumps(${tx_id_idx});print(encoded.hex())")

echo -e "\033[1;33m Building Genesis Contract \033[0m"
aiken blueprint apply -o plutus.json -v genesis.params "${tx_id_hash_cbor}"
aiken blueprint apply -o plutus.json -v genesis.params "${tx_id_idx_cbor}"
aiken blueprint convert -v genesis.params > contracts/genesis_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/genesis_contract.plutus > hashes/genesis.hash
echo -e "\033[1;33m Genesis Contract Hash: $(cat hashes/genesis.hash) \033[0m"

# the pointer token
pointer_prefix="5f6169706f70685f"
pointer_pid=$(cat hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('scripts/py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

# one liner for correct cbor
# requires cbor2
pointer_pid_cbor=$(python3 -c "import cbor2;hex_string='${pointer_pid}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")
pointer_tkn_cbor=$(python3 -c "import cbor2;hex_string='${pointer_tkn}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

# the reference token
dao_pid=$(jq -r '.dao_pid' start_info.json)
dao_tkn=$(jq -r '.dao_tkn' start_info.json)

# one liner for correct cbor
# requires cbor2
dao_pid_cbor=$(python3 -c "import cbor2;hex_string='${dao_pid}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")
dao_tkn_cbor=$(python3 -c "import cbor2;hex_string='${dao_tkn}';data=bytes.fromhex(hex_string);encoded=cbor2.dumps(data);print(encoded.hex())")

echo -e "\033[1;33m Building DAO Contract \033[0m"
aiken blueprint apply -o plutus.json -v dao.params "${pointer_pid_cbor}"
aiken blueprint apply -o plutus.json -v dao.params "${pointer_tkn_cbor}"
aiken blueprint apply -o plutus.json -v dao.params "${dao_pid_cbor}"
aiken blueprint apply -o plutus.json -v dao.params "${dao_tkn_cbor}"
aiken blueprint convert -v dao.params > contracts/dao_contract.plutus

# store the script hash
# requires cardano-cli
cardano-cli transaction policyid --script-file contracts/dao_contract.plutus > hashes/dao.hash
echo -e "\033[1;33m DAO Contract Hash: $(cat hashes/dao.hash) \033[0m"

# end of build
echo -e "\033[1;32m Building Complete! \033[0m"