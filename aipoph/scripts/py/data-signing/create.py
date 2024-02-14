import hashlib

import cbor2


def compute_blake2b_256_hex(data_hex):
    """
    Computes the BLAKE2b 256-bit (32-byte) hash of the given hexadecimal data.

    :param data_hex: The hexadecimal string representation of the data to hash.
    :return: The hexadecimal representation of the BLAKE2b 256-bit hash.
    """
    # Convert the hexadecimal string to bytes
    data_bytes = bytes.fromhex(data_hex)

    # Create a BLAKE2b hash object with a digest size of 32 bytes for BLAKE2b 256-bit
    hasher = hashlib.blake2b(digest_size=32)

    # Update the hasher with the input data
    hasher.update(data_bytes)

    # Return the hexadecimal representation of the hash
    return hasher.hexdigest()


def coloring_hash(coloring):
    coloring_cbor = do_coloring_hash(coloring)
    coloring_cbor_hex = coloring_cbor.hex()
    return compute_blake2b_256_hex(coloring_cbor_hex)


def do_coloring_hash(values):
    """
    Creates a CBOR byte string representing an indefinite-length array
    with the given values.

    :param values: A list of integer values to encode in the array.
    :return: A hexadecimal string representing the encoded CBOR data.
    """
    # Create a bytearray and start with the indefinite-length array prefix (0x9f)
    cbor_bytes = bytearray([0x9f])

    # Encode each value and append it to the array
    for value in values:
        cbor_bytes += cbor2.dumps(value)

    # End the array with the "break" code (0xff)
    cbor_bytes.append(0xff)

    # Convert the bytearray to a bytes object
    graph_cbor = bytes(cbor_bytes)

    return graph_cbor


def graph_hash(graph):
    graph_cbor = do_graph_hash(graph)
    graph_cbor_hex = graph_cbor.hex()
    return compute_blake2b_256_hex(graph_cbor_hex)


def do_graph_hash(edges):
    # Start with the indefinite array prefix
    encoded = bytearray([0x9f])

    # Encode each element with tag 121 and as an indefinite length array
    for element in edges:
        # Tag 121 prefix
        encoded += bytearray([0xd8, 0x79])
        # Start of an indefinite-length array
        encoded += bytearray([0x9f])
        # Encoded edges
        for item in element:
            encoded += cbor2.dumps(item)
        # End of this inner array
        encoded += bytearray([0xff])

    # End of the outer array
    encoded += bytearray([0xff])

    return bytes(encoded)


if __name__ == "__main__":
    graph = [
        [2, 1], [1, 0], [0, 4], [4, 3], [3, 1], [2, 0], [4, 2]
    ]
    the_graph_hash = graph_hash(graph)
    print(f"BLAKE2b hash of '{graph}' (32-byte digest): {the_graph_hash}")
    print(the_graph_hash == "b3064a26269668c85c14d735a77b3b225f5e30ad911870428d3d8daba85e486c")

    coloring = [0, 1, 2, 0, 1]
    the_coloring_hash = coloring_hash(coloring)
    print(f"BLAKE2b hash of '{coloring}' (32-byte digest): {the_coloring_hash}")
    print(the_coloring_hash == "398c36e82ee7a6d7a2bee6fde26fc0c9df373f687b9ec73b5968f9fae8ff92de")
