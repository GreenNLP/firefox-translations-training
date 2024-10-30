import re
import sys

def decrement_fuzzy_breaks(input_file, output_file):
    with open(input_file, 'r') as file:
        content = file.read()

    # Find all FUZZY_BREAK_n occurrences
    fuzzy_breaks = re.findall(r'FUZZY_BREAK_([1-9])', content)
    
    # Convert found numbers to integers
    fuzzy_breaks = list(map(int, fuzzy_breaks))

    if not fuzzy_breaks:
        print("No FUZZY_BREAK_n tokens found.")
        return

    # Find the minimum value of n
    min_n = min(fuzzy_breaks)

    # Define a function to decrement FUZZY_BREAK_n, but keep the minimum unchanged
    def replace_fuzzy_break(match):
        n = int(match.group(1))
        if n == min_n:
            return f"FUZZY_BREAK_{n}"
        else:
            return f"FUZZY_BREAK_{n - 1}"

    # Replace FUZZY_BREAK_n tokens in the content
    new_content = re.sub(r'FUZZY_BREAK_([1-9])', replace_fuzzy_break, content)

    # Write the result to the output file
    with open(output_file, 'w') as file:
        file.write(new_content)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    decrement_fuzzy_breaks(input_file, output_file)

