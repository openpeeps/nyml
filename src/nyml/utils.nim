proc cutLast*(text: string, cuts=2): string =
    # Remove chars from the end of the string
    try: text[0 .. ^cuts]
    except RangeDefect: text
