import numpy as np
import torch

<<<<<<< HEAD
def save_to_file(tensor, filename):
    # Placeholder function, implement saving logic if needed
    pass

def fp32_maker():
    # Helper function to convert hex to float32 using struct for bit-level manipulation
    def hex_to_float32(hex_str):
        # Convert hex to bytes, then unpack as float32
        return struct.unpack('!f', bytes.fromhex(hex_str))[0]
=======



>>>>>>> parent of 4c16995 (id_compare unit changed for multiple N 24-11-05 18:21)


<<<<<<< HEAD
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
    # Generate a unique random ID1
    id1 = torch.randperm(max_id)[:id_size].to(torch.int32)
    
    # Start by copying all elements of id1 to id2
    id2 = id1.clone()

    # Randomly choose a subset of indices to replace with new random values in id2
    num_to_replace = torch.randint(1, (id_size * 2) // 3, (1,)).item()
    replace_indices = torch.randperm(id1.size(0))[:num_to_replace]
    
    # Replace chosen indices in id2 with unique random values not in id1
    new_values = torch.randint(0, max_id, (num_to_replace,), dtype=torch.int32)
    for idx in range(num_to_replace):
        while new_values[idx].item() in id1:
            new_values[idx] = torch.randint(0, max_id, (1,), dtype=torch.int32)
        id2[replace_indices[idx]] = new_values[idx]

    print("\nID1:", id1)
    print("\nID2:", id2)
    
    # Identify overlapping indices and ensure they are the same
    overlap = (id1 == id2).nonzero(as_tuple=True)[0]
    print("Overlap indices:", overlap)

if __name__ == "__main__":
    mode = "fp32"
    
    gaussian_id_maker()
=======

if __name__ == "__main__":
    mode = "bf16"
>>>>>>> parent of 4c16995 (id_compare unit changed for multiple N 24-11-05 18:21)
    
    if mode == "bf16":
        pass
    elif mode == "fp24":
        pass
    elif mode == "fp32":
<<<<<<< HEAD
        tensors = fp32_maker() # dictionary 형태, 각 ID당 값들 정해져 있음.
        
        

=======
        pass
>>>>>>> parent of 4c16995 (id_compare unit changed for multiple N 24-11-05 18:21)
