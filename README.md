### NMSA Based Error Correction Algorithm for Quantum Key Distribution
This code is based on the paper "FPGA Accelerated Adaptive LDPC-based Quantum
Error Correction by Bitwise Pipeline Parallelism" by Bingze Ye, Jiyuan Liu, He Li

##Implementation 
This algorithm processes probability equations laid on the check nodes and variable nodes of an LDPC matrix.
The equations are provided in the research paper above.
Implemented in Vivado 2024.1 

##Code 
There are 6 modules and one BRAM macro storing the positions of the 1's present in the LDPC matrix
The BRAM was created using the Block memory generator present in vivado itself with 100 rows each 72 bits.

**Check_Nodes_Process_Unit** module does the calculation of the internal message called Rji with the input being the internal message of the Variable_Node_Process_Unit.

**Variable_Node_Process_Unit** calculates internal message called Qij using the LLR of the input bit and the Rji provided by the CNPU.

**Decision_Unit** outputs the corrected bit. It takes the Rji as input along with the Lpi and calculates the sign of the result. If positive , the output is 1 , else 0.

**Initialisation_Block** fetches the LLR of the input bit based on the qber provided. It takes the appropriate LLR from a lookup table.

**Lookup_table_eq6** holds the various LPi values calculated pre hand. These Lpi values are calculated prehand with QBER as a function and stored. The lookup table stores LPi values of QBER ranging from 0.01 to 0.11.

**LDPC_top** integrates the above mentioned blocks and acts as a controller receiving and sending data to various blocks. It also runs a loop where in the Rji and Qij is calculated for that number of times to get a proper error corrected codeword.


##Notes
The code is ready to run but you will have to generate an LDPC matrix of said size , the above code runs for an 80 * 100 LDPC matrix
Here's a simple python script to generate a LDPC matrix
```import numpy as np
# Generate balanced LDPC matrix (80 rows, 100 columns)
def generate_balanced_ldpc(m=80, n=100, dv=4, dc=5):
    assert m * dc == n * dv, "Invalid parameters: m*dc must equal n*dv"
    H = np.zeros((m, n), dtype=int)
    row_weights = [0] * m

    for col in range(n):
        placed = 0
        sorted_rows = sorted(range(m), key=lambda r: row_weights[r])
        for row in sorted_rows:
            if row_weights[row] < dc and H[row, col] == 0:
                H[row, col] = 1
                row_weights[row] += 1
                placed += 1
            if placed == dv:
                break
        if placed < dv:
            raise RuntimeError(f"Couldn't place {dv} ones in column {col}")
    return H

# Save LDPC matrix to .alist format
def save_to_alist(H, filename):
    m, n = H.shape
    col_weights = np.sum(H, axis=0).astype(int)
    row_weights = np.sum(H, axis=1).astype(int)
    max_col = col_weights.max()
    max_row = row_weights.max()

    with open(filename, 'w') as f:
        f.write(f"{n} {m}\n")
        f.write(f"{max_col} {max_row}\n")
        f.write(' '.join(map(str, col_weights)) + '\n')
        f.write(' '.join(map(str, row_weights)) + '\n')

        for col in range(n):
            indices = np.where(H[:, col])[0] + 1
            indices = list(indices) + [0] * (max_col - len(indices))
            f.write(' '.join(map(str, indices)) + '\n')

        for row in range(m):
            indices = np.where(H[row])[0] + 1
            indices = list(indices) + [0] * (max_row - len(indices))
            f.write(' '.join(map(str, indices)) + '\n')

# Generate and save
H = generate_balanced_ldpc()
save_to_alist(H, 'ldpc_80x100.alist')
```
Convert the above matrix into a .coe file for reference.
The positions of the 1's both column wise and row wise also has to be taken from the matrix , here's the python script for that as well
```
import csv

# Change this to match your uploaded file name in Colab
input_coe_path = "matrix_cr2_T.coe"

output_positions_coe = "positions2T_colparse.coe"
output_positions_csv = "positions2T_colparse.csv"

def parse_ldpc_coe_to_hex(input_coe_path, output_positions_coe, output_positions_csv):
    with open(input_coe_path, 'r') as f:
        lines = f.readlines()

    # Skip until initialization vector
    data_lines = []
    start_found = False
    for line in lines:
        line = line.strip()
        if not start_found:
            if line.lower().startswith("memory_initialization_vector"):
                start_found = True
            continue
        line = line.replace(',', '').replace(';', '').strip()
        if line:
            data_lines.append(line)

    # Build H matrix
    H = [[int(bit) for bit in row.strip()] for row in data_lines]
    num_rows = len(H)
    num_cols = len(H[0]) if num_rows > 0 else 0

    # Find row positions of 1's in each column
    positions_per_col = []
    for col in range(num_cols):
        positions = [row for row in range(num_rows) if H[row][col] == 1]
        positions_per_col.append(positions)

    # Save .coe (HEX format, no spaces)
    with open(output_positions_coe, 'w') as fcoe:
        fcoe.write("memory_initialization_radix=16;\n")
        fcoe.write("memory_initialization_vector=\n")
        for idx, positions in enumerate(positions_per_col):
            hex_values = [format(pos, '02X') for pos in positions]  # 7-bit → 2 hex digits
            hex_str = "".join(hex_values)  # concatenate without spaces
            end_char = ',' if idx < num_cols - 1 else ';'
            fcoe.write(f"{hex_str}{end_char}\n")

    # Save CSV for reference
    with open(output_positions_csv, 'w', newline='') as fcsv:
        writer = csv.writer(fcsv)
        writer.writerow(["Column Index", "Row Positions (Hex)"])
        for idx, positions in enumerate(positions_per_col):
            hex_values = [format(pos, '02X') for pos in positions]
            writer.writerow([idx, "".join(hex_values)])

# Run parser
parse_ldpc_coe_to_hex(input_coe_path, output_positions_coe, output_positions_csv)

print("Done. Files saved as:")
print(output_positions_coe)
print(output_positions_csv)
```
You can upload this coe file into the Block Memory Generator in Vivado and run the whole LDPC system.

