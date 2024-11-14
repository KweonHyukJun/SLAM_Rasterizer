import glob
import os

# Directory containing your input hex files
input_directory = "../hex/pixel_group/office0_fp32_10000_1595_100"  # Update this if files are in a different folder

# Get a list of all input hex files matching the pattern
input_files = glob.glob(os.path.join(input_directory, "gaussian_id_out_*.hex"))

# Process each file
for input_file in input_files:
    # Define the output file name based on the input file name
    output_file = input_file.replace("gaussian_id_out_", "gaussian_id_out_filtered_")
    
    # Open the input file and create a new output file
    with open(input_file, "r") as infile, open(output_file, "w") as outfile:
        for line in infile:
            # Strip newline characters and whitespace
            value = line.strip()
            
            # Write to output file only if value is not '00000000'
            if value != "00000000":
                outfile.write(value + "\n")
    
    print(f"Filtered hex file saved as '{output_file}'")
