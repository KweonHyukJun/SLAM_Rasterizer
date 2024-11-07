import numpy as np
import torch
import struct

max_id = 200 # ID range
pixel_size = 4 # 한번에 받을 pixel 수 (0~3, 4~7은 동타이밍)
id_size = 100 * pixel_size # Data size => 100 * 4 로 처리
num_to_replace = 30 # different IDs

N_TEST = 200


def save_to_file(tensor_data, filename):
    """Save tensor values as hexadecimal IEEE 754 format in a .hex file."""
    with open(filename, 'w') as f:
        for tensor in tensor_data:
            hex_values = [f"{struct.unpack('!I', struct.pack('!f', val.item()))[0]:08x}" for val in tensor]
            f.write(" ".join(hex_values) + "\n")

def save_id_sequence_to_file(id_sequence, filename):
    """Save ID sequence as hexadecimal integers in a .hex file."""
    with open(filename, 'w') as f:
        for id_val in id_sequence:
            f.write(f"{id_val.item():08x}\n")
            
def fp32_maker():
    # Helper function to convert hex to float32 using struct for bit-level manipulation
    
    def hex_to_float32(hex_str):
        # Convert hex to bytes, then unpack as float32
        return struct.unpack('!f', bytes.fromhex(hex_str))[0]

    # Base values from hexadecimal inputs
    dL_dcolor_base = hex_to_float32("32b60b8f")
    dL_ddepth_base = hex_to_float32("ab72016c")
    dL_dmean2D_bases = [hex_to_float32("b126dcd6"), hex_to_float32("2fba37bd")]
    dL_dconic_bases = [hex_to_float32("30292b9d"), hex_to_float32("30c3d25f"),
                       hex_to_float32("00000000"), hex_to_float32("3162ac02")]
    dL_dopacity_base = hex_to_float32("2b2feec5")

    # Generate tensors with slight random variations around each base value
    def generate_near_values(base_value, shape, variance=0.01):
        random_offsets = (torch.rand(shape) * 2 - 1) * variance  # Uniform range [-variance, variance]
        return torch.tensor([base_value], dtype=torch.float32).expand(shape) * (1 + random_offsets)

    # Creating the series with values close to each base
    dL_dcolor = generate_near_values(dL_dcolor_base, (max_id, 3))
    dL_ddepth = generate_near_values(dL_ddepth_base, (max_id, 1))
    dL_dmean2D = torch.cat([generate_near_values(val, (max_id, 1)) for val in dL_dmean2D_bases], dim=1)
    dL_dconic = torch.cat([generate_near_values(val, (max_id, 1)) for val in dL_dconic_bases], dim=1)
    dL_dopacity = generate_near_values(dL_dopacity_base, (max_id, 1))

    # Return all tensors in a dictionary
    return {
        "dL_dcolor": dL_dcolor,
        "dL_ddepth": dL_ddepth,
        "dL_dmean2D": dL_dmean2D,
        "dL_dconic": dL_dconic,
        "dL_dopacity": dL_dopacity
    }
    
def gaussian_id_maker():
    id_sequence = torch.empty(id_size, dtype=torch.int32)  # Initialize an empty tensor for IDs
    current_max_id = 1  # Start generating IDs from 1

    for i in range(0, id_size, pixel_size):
        # Decide randomly if the current block should have the same ID or unique IDs
        if torch.rand(1).item() > 0.5:  # 50% chance to have the same ID in the block
            unique_id = current_max_id
            id_sequence[i:i + pixel_size] = unique_id
            current_max_id += 1  # Move to the next unique ID for future blocks
        else:  # Otherwise, assign unique IDs within this block
            unique_ids = torch.arange(current_max_id, current_max_id + pixel_size)
            id_sequence[i:i + pixel_size] = unique_ids
            current_max_id += pixel_size  # Increment by pixel_size for next block
        
    # Randomly shuffle the overall sequence to add variability
    id_sequence = id_sequence[torch.randperm(id_sequence.size(0))]

    # Print the ID sequence for testing purposes
    print("Generated ID sequence:", id_sequence)
    return id_sequence



def create_individual_hex_files(tensors, id_sequence):
    """ Create individual .hex files for each tensor based on ID sequence. """
    for tensor_name, tensor_data in tensors.items():
        data_to_save = [tensor_data[id_val] for id_val in id_sequence]
        filename = f"{tensor_name}.hex"
        save_to_file(data_to_save, filename)
    

def create_valid_hex_files():
    """Create a .hex file with '1' (in hex '00000001') repeated id_size times."""
    filename = f"i_valid.hex"
    with open(filename, 'w') as f:
        for _ in range(id_size * pixel_size):
            f.write("1\n")
        for __ in range(pixel_size * (N_TEST  - id_size)):
            f.write("0\n")



if __name__ == "__main__":
    mode = "fp32"
    
    id_sequence = gaussian_id_maker()
    save_id_sequence_to_file(id_sequence, "gaussian_id.hex")
    
    
    if mode == "bf16":
        pass
    elif mode == "fp24":
        pass
    
    elif mode == "fp32":
        # tensors = fp32_maker() # dictionary 형태, 각 ID당 값들 정해져 있음., id1, id2와 독립적으로 분포
        # # Create individual hex files for each tensor and ID sequence
        # create_individual_hex_files(tensors, id_sequence)
        # create_valid_hex_files()
        
        print("Hex files created for id sequences.")

