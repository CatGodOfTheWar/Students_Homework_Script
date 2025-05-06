# Set initial directories
set zip_dir "./zips"                      # Directory containing .zip files
set temp_dir "./temp_dir"                # Temporary directory for extraction
set output_dir "./output_dir"            # Directory for output files

# Create initial directories
file mkdir $temp_dir                     
file mkdir $output_dir                   

# Set the file where results will be written
set output_file "$output_dir/results.txt"  

# Find all .zip files in the /zips folder
set zip_files [glob -directory $zip_dir *.zip] 
set results_dict {}                       # Dictionary to store results
set total [llength $zip_files]            # Total number of .zip files
set index 1                               # Index for progress tracking

# Function to extract ports from Verilog files
# This function identifies input and output ports and their types (vector/scalar)
proc extract_ports {filename} {
    set fh [open $filename r]
    set content [read $fh]
    close $fh

    set input_ports {}
    set output_ports {}

    foreach line [split $content "\n"] {
        set line [string trim $line]

        # Skip empty lines or comments
        if {$line eq "" || [string match "//*" $line]} { continue }

        # Remove inline comments
        if {[regexp {(.*)//} $line -> clean_line]} {
            set line [string trim $clean_line]
        }

        # Match input ports (vector type)
        if {[regexp {input\s+(wire\s*|\s*)\[\d+:\d+\]\s*(\w+)} $line -> _ name]} {
            lappend input_ports [list $name vector]
            continue
        }

        # Match input ports (scalar type, multiple names)
        if {[regexp {input\s+(wire\s*)?([^;]+);?} $line -> _ names]} {
            foreach part [split $names ","] {
                set clean [string trim $part]
                if {![regexp {\[\d+:\d+\]} $clean]} {
                    lappend input_ports [list $clean scalar]
                }
            }
            continue
        }

        # Match input ports (scalar type, single name)
        if {[regexp {input\s+(wire\s*)?(\w+);?} $line -> _ name]} {
            lappend input_ports [list $name scalar]
            continue
        }

        # Match output ports (vector type)
        if {[regexp {output\s+(wire\s*|reg\s*|\s*)\[\d+:\d+\]\s*(\w+)} $line -> _ name]} {
            lappend output_ports [list $name vector]
            continue
        }

        # Match output ports (scalar type, multiple names)
        if {[regexp {output\s+(wire\s*|reg\s*|\s*)([^;]+);?} $line -> _ names]} {
            foreach part [split $names ","] {
                set clean [string trim $part]
                if {![regexp {\[\d+:\d+\]} $clean]} {
                    lappend output_ports [list $clean scalar]
                }
            }
            continue
        }

        # Match output ports (scalar type, single name)
        if {[regexp {output\s+(wire\s*|reg\s*|\s*)(\w+);?} $line -> _ name]} {
            lappend output_ports [list $name scalar]
            continue
        }
    }

    # Return the extracted input and output ports
    return [list $input_ports $output_ports]
}

# Process each .zip archive
foreach zip_file $zip_files {
    puts "\n==> [$index/$total] Processing archive: [file tail $zip_file]" 

    # Clean the temporary directory before processing each archive
    catch {file delete -force $temp_dir}
    file mkdir $temp_dir

    # Extract the .zip archive
    if {[catch { exec "C:/Program Files/7-Zip/7z.exe" x "-o$temp_dir" $zip_file } err]} {
        dict set results_dict "ERROR_[file tail $zip_file]" "Extraction failed: $err" 
        incr index
        continue
    }

    # Find all Verilog files in the extracted directory
    set all_verilog_files [glob -nocomplain "$temp_dir/*.v" "$temp_dir/**/*.v"]
    set file_c ""  # File for comparator module
    set file_s ""  # File for student module

    # Identify specific Verilog files based on naming patterns
    foreach f $all_verilog_files {
        set filename [file tail $f]
        if {![string match "tb_*" $filename]} {
                if {![string match "TB_*" $filename]} {
                    if {[string match "*_BCD7Seg_c.v" $filename]} {
                    set file_c $f
                } elseif {[string match "*_BCD7Seg_s.v" $filename]} {
                    set file_s $f
                }
            }
        }
    }

    # Check if required files are present
    if {$file_c eq "" || $file_s eq ""} {
        dict set results_dict "UNKNOWN_[file tail $zip_file]" "Missing *_BCD7Seg_c.v or *_BCD7Seg_s.v for $zip_file\n"
        incr index
        continue
    }

    # Extract prefix from the comparator file name
    if {![regexp {([^_]+)_BCD7Seg_c.v} [file tail $file_c] -> prefix]} {
        puts "Error: Could not extract prefix from [file tail $file_c]"
        incr index
        continue
    }

    set module_name_c [file rootname [file tail $file_c]] 
    set module_name_s [file rootname [file tail $file_s]]
    puts "Detected prefix: $prefix"

    # Extract ports from the comparator and student files
    foreach {c_inputs c_outputs} [extract_ports $file_c] {break}
    foreach {s_inputs s_outputs} [extract_ports $file_s] {break}

    # Build port mapping for comparator (c)
    set uut_c_ports ""
    set bit_index 0
    foreach port $c_inputs {
        set name [lindex $port 0]
        set type [lindex $port 1]
        if {$name eq ""} { continue }
        if {$type eq "vector"} {
            append uut_c_ports ".${name}(in), "
        } else {
            append uut_c_ports ".${name}(in\[$bit_index\]), "
            incr bit_index
        }
    }
    set bit_index 0
    foreach port $c_outputs {
        set name [lindex $port 0]
        set type [lindex $port 1]
        if {$name eq ""} { continue }
        if {$type eq "vector"} {
            append uut_c_ports ".${name}(out_c), "
        } else {
            append uut_c_ports ".${name}(out_c\[$bit_index\]), "
            incr bit_index
        }
    }
    set uut_c_ports [string trimright $uut_c_ports ", "]

    # Build port mapping for student (s)
    set uut_s_ports ""
    set bit_index 0
    foreach port $s_inputs {
        set name [lindex $port 0]
        set type [lindex $port 1]
        if {$name eq ""} { continue }
        if {$type eq "vector"} {
            append uut_s_ports ".${name}(in), "
        } else {
            append uut_s_ports ".${name}(in\[$bit_index\]), "
            incr bit_index
        }
    }
    set bit_index 0
    foreach port $s_outputs {
        set name [lindex $port 0]
        set type [lindex $port 1]
        if {$name eq ""} { continue }
        if {$type eq "vector"} {
            append uut_s_ports ".${name}(out_s), "
        } else {
            append uut_s_ports ".${name}(out_s\[$bit_index\]), "
            incr bit_index
        }
    }
    set uut_s_ports [string trimright $uut_s_ports ", "]

    puts "==> Ports for $prefix:"
    puts "uut_c_ports = $uut_c_ports"
    puts "uut_s_ports = $uut_s_ports"

    # Create a unique project for each archive
    set project_dir "$temp_dir/project_$prefix"
    create_project "test_project_$prefix" "$project_dir" -part xc7s50csga324-1

    add_files $file_c
    add_files $file_s

    puts "$file_c"
    puts "$file_s"

    # Generate a testbench file for simulation
    set testbench_file "$temp_dir/testbench_$prefix.v"
    set comparison_result_path [file normalize "$temp_dir/comparison_result_$prefix.txt"]

    set tb_fh [open $testbench_file w]
    puts $tb_fh {
    `timescale 1ns/1ps

    module testbench;
        reg [3:0] in;
        wire [6:0] out_c, out_s;

        uut_c uut_c (UUT_C_PORTS);
        uut_s uut_s (UUT_S_PORTS);

        integer i;
        integer match_count = 0;
        reg [3:0] failed_cases[15:0];
        integer fail_index = 0;
        integer fd;

        initial begin
            $display("Starting comparison...");
            for (i = 0; i < 16; i = i + 1) begin
                in = i;
                #100;
                if (out_c === out_s) begin
                    match_count = match_count + 1;
                end else begin
                    failed_cases[fail_index] = in;
                    fail_index = fail_index + 1;
                end
            end

            fd = $fopen("COMPARISON_PATH", "w");
            if (match_count == 16) begin
                $fdisplay(fd, "PREFIX_REPLACE/ARCHIVE - match found for all , ");
            end else begin
                $fwrite(fd, "PREFIX_REPLACE/ARCHIVE - match found for %0d out of 16, mismatch at ", match_count);
                for (i = 0; i < fail_index; i = i + 1) begin
                    $fwrite(fd, "%04b", failed_cases[i]);
                    if (i != fail_index - 1) $fwrite(fd, " , ");
                end
                $fdisplay(fd, "");
            end
            $fclose(fd);
            $finish;
        end
    endmodule
    }
    close $tb_fh

    # Replace placeholders in the testbench file
    set tb_fh [open $testbench_file r]
    set file_data [read $tb_fh]
    close $tb_fh

    set file_data [string map [list \
        PREFIX_REPLACE $prefix \
        uut_c $module_name_c \
        uut_s $module_name_s \
        UUT_C_PORTS $uut_c_ports \
        UUT_S_PORTS $uut_s_ports \
        COMPARISON_PATH $comparison_result_path \
        ARCHIVE [file tail $zip_file] \
    ] $file_data]

    set tb_fh [open $testbench_file w]
    puts -nonewline $tb_fh $file_data
    close $tb_fh

    # Launch simulation
    puts "Launching simulation..."
    add_files $testbench_file
    update_compile_order -fileset sim_1
    launch_simulation
    run -all

    # Read the simulation result
    puts "Reading result from comparison_result_$prefix.txt..."
    if {[file exists $comparison_result_path]} {
        set fd [open $comparison_result_path r]
        set line [read $fd]
        close $fd
        dict set results_dict $prefix $line
        puts "$line"
    } else {
        dict set results_dict $prefix "$prefix - simulation failed or result missing"
        puts "Simulation failed or result file is missing."
    }

    close_sim
    close_project
    incr index
}

# At the end, clean up the temporary directory
puts "\n==> Cleaning up the temporary folder..."
catch {file delete -force $temp_dir}

# Write the final results to the output file
puts "\n==> Writing final results to: $output_file"
set out [open $output_file "w"]
foreach prefix [lsort [dict keys $results_dict]] {
    puts -nonewline $out "[dict get $results_dict $prefix]"
}
close $out
puts "\nAutomated testing has been completed!"
