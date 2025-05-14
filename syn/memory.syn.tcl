# Define memory parameters
set mem1_banks 16
set mem1_depth 2048
set mem1_data_width 352

set mem2_banks 16
set mem2_depth 16
set mem2_data_width 172

set mem3_banks 4
set mem3_depth 512
set mem3_data_width 320

# Create Memory 1 (16 banks, 2048 depth, 352 bits)
for {set i 0} {$i < $mem1_banks} {incr i} {
    create_memory -type sram \
                  -size $mem1_depth \
                  -data_width $mem1_data_width \
                  -num_ports 2
}

# Create Memory 2 (16 banks, 16 depth, 172 bits)
for {set i 0} {$i < $mem2_banks} {incr i} {
    create_memory -type sram \
                  -size $mem2_depth \
                  -data_width $mem2_data_width \
                  -num_ports 2
}

# Create Memory 3 (4 banks, 512 depth, 320 bits)
for {set i 0} {$i < $mem3_banks} {incr i} {
    create_memory -type sram \
                  -size $mem3_depth \
                  -data_width $mem3_data_width \
                  -num_ports 2
}

# Generate area and power reports for the created memories and overwrite into the same file
set combined_report "combined_report.rpt"

# Overwrite area report into the file
set fp [open $combined_report "w"]
report_area > $fp
close $fp

# Overwrite power report into the same file, appending after the area report
set fp [open $combined_report "a"]
report_power -hier -analysis_effort medium > $fp
close $fp

# Optional: Print the contents of the report to the terminal as well
puts "Area and Power reports have been saved to: $combined_report"
