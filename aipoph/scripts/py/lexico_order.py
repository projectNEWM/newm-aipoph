def compare_strings(x: str, y: str) -> int:
    if x < y:
        return 0
    else:
        return 1


if __name__ == "__main__":
    # Test the function
    x = "db19ec607c3bf2628502f7e9daa67f448e88dc76e790462cdd89b858b2c9bc98#0"
    y = "d053d4af362436023629cf67b9990aefb9782119744383f102e17892463ae11b#1"

    result = compare_strings(x, y)
    print(result)  # Output: 1

    # Test the function
    x = "d053d4af362436023629cf67b9990aefb9782119744383f102e17892463ae11b#0"
    y = "d053d4af362436023629cf67b9990aefb9782119744383f102e17892463ae11b#1"

    result = compare_strings(x, y)
    print(result)  # Output: 0
