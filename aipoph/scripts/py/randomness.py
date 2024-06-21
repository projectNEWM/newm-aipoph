import secrets


def number() -> int:
    """
    Generate a random number between 0 and 2^64 - 1.

    Returns:
        int: A random number within the specified range.
    """
    # Generate a random 64-bit number but bound by the max datum int size
    n = secrets.randbits(64)
    if n <= pow(2, 64) - 1:
        return n
    else:
        return number()


def string() -> str:
    """
    Generate a random hex string of length 64.

    Returns:
        str: A random hex string of length 64.
    """
    # Generate a 64-length hex string (32 bytes, each byte represented by 2 hex digits)
    return secrets.token_hex(32)
