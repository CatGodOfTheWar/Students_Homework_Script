# Students Homework Script

This project automates the testing of Verilog modules submitted as homework by students. The script processes `.zip` archives containing Verilog files, extracts the files, and compares the outputs of a comparator module (`*_BCD7Seg_c.v`) and a student module (`*_BCD7Seg_s.v`) using a generated testbench.

## Features

- Automatically extracts `.zip` archives containing Verilog files.
- Identifies and processes specific Verilog files based on naming patterns.
- Extracts input and output ports from Verilog modules.
- Generates a testbench for simulation and comparison of outputs.
- Logs results of the comparison for each archive.

## Requirements

- [7-Zip](https://www.7-zip.org/) installed and accessible via the path `C:/Program Files/7-Zip/7z.exe`.
- A Verilog simulation tool (e.g., Vivado) for running the generated testbench.
- TCL interpreter to execute the script.

## Directory Structure

- `./zips`: Directory containing `.zip` files to be processed.
- `./temp_dir`: Temporary directory for extracting files.
- `./output_dir`: Directory where results and logs will be saved.

## Usage

1. Place all `.zip` files containing Verilog modules in the `./zips` directory.
2. Run the script using a TCL console in Vivado:
   ```sh
    source Script.tcl