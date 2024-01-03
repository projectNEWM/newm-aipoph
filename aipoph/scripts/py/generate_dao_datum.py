import json
import pathlib
import subprocess


def to_hex(string: str) -> str:
    """
    Returns the hexencoded version of a string.

    Args:
        string (str): A string to encode into hexadecimal.

    Returns:
        str: A hex string
    """
    if not isinstance(string, str):
        raise TypeError("Input Must Be A String")

    # hex encode
    return string.encode().hex()


def read_json_file(file_path: str) -> dict | None:
    """
    Reads a JSON file and returns the data as a Python dictionary.

    Args:
        file_path (str): Path to the JSON file.

    Returns:
        Optional[Dict[Any, Any]]: Dictionary containing the data from the JSON file,
        or None if an error occurs.
    """
    try:
        with open(file_path, 'r') as file:
            return json.load(file)
    except FileNotFoundError:
        print(f"File not found: {file_path}")
    except json.JSONDecodeError:
        print(f"Error decoding JSON from the file: {file_path}")
    return None


def write_json_file(data: dict, file_path: str) -> None:
    """
    Writes a Python dictionary to a JSON file.

    Args:
        data (dict): Dictionary to be written to the file.
        file_path (str): Path where the JSON file will be saved.
    """
    try:
        with open(file_path, 'w') as file:
            json.dump(data, file, indent=2)
    except IOError:
        print(f"Error writing to file: {file_path}")


def get_dao_data() -> dict:
    """
    Reads a dao data from the json file and returns the dict.

    Returns:
        dict: Dictionary containing the data
    """
    # Get the current script's directory (py folder)
    current_script_path = pathlib.Path(__file__).parent

    # Navigate to the parent directory (project folder)
    parent_directory = current_script_path.parent

    # Construct the path to the file in the data folder
    data_file_path = parent_directory / 'data' / 'dao' / 'dao-data.json'

    dao_data = read_json_file(data_file_path)
    return dao_data


def byte_map_map_element(name: str) -> dict:
    return {
        "k": {
            "bytes": to_hex(name)
        },
        "v": {
            "map": []
        }
    }


def byte_int_map_element(name: str, number: int) -> dict:
    return {
        "k": {
            "bytes": to_hex(name)
        },
        "v": {
            "int": int(number)
        }
    }


def byte_byte_map_element(name: str, contract: str) -> dict:
    return {
        "k": {
            "bytes": to_hex(name)
        },
        "v": {
            "bytes": contract
        }
    }


def compute_contract_hash(contract_file: str) -> str:
    """ Compute the hash of the contract using the cardano-cli transaction
    policyid function. The cli is ran with subprocess.

    Args:
        contract (str): The path to the cardano smart contract.

    Returns:
        str: The contract hash or an empty string.
    """
    # Get the current script's directory (py folder)
    current_script_path = pathlib.Path(__file__).parent

    # Navigate to the parent directory (project folder)
    parent_directory = current_script_path.parent.parent

    data_file_path = parent_directory / 'contracts' / (contract_file + '.plutus')

    try:
        output = subprocess.run(
            [
                'cardano-cli',
                'transaction',
                'policyid',
                '--script-file',
                data_file_path
            ],
            check=True,
            capture_output=True,
            text=True
        )
        return output.stdout.rstrip()
    except subprocess.CalledProcessError:
        return ""


def generate_datum():
    base = {
        "constructor": 0,
        "fields": [
            {
                "map": []
            },
            {
                "int": 1
            }
        ]
    }

    dao_data = get_dao_data()
    for counter, outer_key in enumerate(dao_data):
        # print(outer_key)
        # map a byte map map lement
        base['fields'][0]['map'].append(byte_map_map_element(outer_key))
        for inner_key in dao_data[outer_key]:
            # print(inner_key)
            value = dao_data[outer_key][inner_key]
            if isinstance(value, str):
                # we need the byte_byte map element

                contract_hash = compute_contract_hash(inner_key)
                base['fields'][0]['map'][counter]['v']['map'].append(byte_byte_map_element(inner_key, contract_hash))
            elif isinstance(value, int):
                # we need the byte_int map element
                base['fields'][0]['map'][counter]['v']['map'].append(byte_int_map_element(inner_key, value))
            else:
                pass
    # Get the current script's directory (py folder)
    current_script_path = pathlib.Path(__file__).parent

    # Navigate to the parent directory (project folder)
    parent_directory = current_script_path.parent

    # Construct the path to the file in the data folder
    data_file_path = parent_directory / 'data' / 'dao' / 'updated-dao-datum.json'
    write_json_file(base, data_file_path)


if "__main__" == __name__:
    generate_datum()
