import os

def find_and_save_index(directory):
    for i in range(16):  # Assuming the range of i is 0 to 99
        filename = f"gaussian_id_in_{i}.hex"
        filepath = os.path.join(directory, filename)
        if os.path.isfile(filepath):
            with open(filepath, 'r') as file:
                lines = file.readlines()
                for index, line in enumerate(lines):
                    if line.strip() == "00000000":
                        print(f'file at {i}, and line {index}')
                        
                        new_filename = f"i_valid_{i}.hex"
                        new_filepath = os.path.join(directory, new_filename)
                        with open(new_filepath, 'w') as new_file:
                            for j in range(index):
                                new_file.write("1\n")
                            for j in range(index + 1, 1024):
                                new_file.write("0\n")
                        break
                        # with open("parameter_index.txt", 'a') as output_file:
                        #     output_file.write(f"{i} {index}\n")
                        # break
                    # with open("parameter_index.txt", 'a') as output_file:
                    #     output_file.write(f"{i}\n")

# directory = "../hex/pixel_group/rgbd_dataset_freiburg3_long_office_household_fp32/"
directory = "../hex/pixel_group/office0_fp32_10000_1595_100/"

find_and_save_index(directory)