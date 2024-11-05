def read_hex_file(file_path):
    with open(file_path, 'r') as file:
        return [line.strip() for line in file.readlines()]

def save_selected_dL_dcolor(skip_data, dL_dcolor_data, output_file):
    with open(output_file, 'w') as file:
        for i in range(len(skip_data)):
            if skip_data[i] == '0':
                file.write(dL_dcolor_data[i] + '\n')

# Load data from files
skip_data = read_hex_file('../hex/fp32_v2/skip.hex')  # contains 0s and 1s
dL_dcolor_data = read_hex_file('../hex/fp32_v2/dL_dcolor.hex')  # hex values
dL_dconic_data = read_hex_file('../hex/fp32_v2/dL_dconic.hex')  # hex values
dL_dmean2D_data = read_hex_file('../hex/fp32_v2/dL_dmean2D.hex')  # hex values
dL_ddepth_data = read_hex_file('../hex/fp32_v2/dL_ddepths.hex')  # hex values
dL_dopacity_data = read_hex_file('../hex/fp32_v2/dL_dopacity.hex')  # hex values

# alpha_data = read_hex_file('../hex/fp32_v2/alpha.hex')  # hex values
# G_data = read_hex_file('../hex/fp32_v2/G.hex')  # hex values
# d_data = read_hex_file('../hex/fp32_v2/d.hex')  # hex values
conic_opacity_data = read_hex_file('../hex/fp32_v2/conic_opacity.hex')  # hex values
gaussian_color_data = read_hex_file('../hex/fp32_v2/gaussian_color.hex')  # hex values
gaussian_depth_data = read_hex_file('../hex/fp32_v2/gaussian_depth.hex')  # hex values
gaussian_id_data = read_hex_file('../hex/fp32_v2/gaussian_id.hex')  # hex values

# Save the dL_dcolor data when skip is 0
save_selected_dL_dcolor(skip_data, dL_dcolor_data, '../hex/fp32_v2/output_dL_dcolor.hex')
save_selected_dL_dcolor(skip_data, dL_dconic_data, '../hex/fp32_v2/output_dL_dconic.hex')
save_selected_dL_dcolor(skip_data, dL_dmean2D_data, '../hex/fp32_v2/output_dL_dmean2D.hex')
save_selected_dL_dcolor(skip_data, dL_ddepth_data, '../hex/fp32_v2/output_dL_ddepth.hex')
save_selected_dL_dcolor(skip_data, dL_dopacity_data, '../hex/fp32_v2/output_dL_dopacity.hex')
# save_selected_dL_dcolor(skip_data, alpha_data, '../hex/fp32_v2/output_alpha.hex')
# save_selected_dL_dcolor(skip_data, G_data, '../hex/fp32_v2/output_G.hex')
# save_selected_dL_dcolor(skip_data, d_data, '../hex/fp32_v2/output_d.hex')
save_selected_dL_dcolor(skip_data, conic_opacity_data, '../hex/fp32_v2/output_conic_opacity.hex')
save_selected_dL_dcolor(skip_data, gaussian_color_data, '../hex/fp32_v2/output_gaussian_color.hex')
save_selected_dL_dcolor(skip_data, gaussian_depth_data, '../hex/fp32_v2/output_gaussian_depth.hex')
save_selected_dL_dcolor(skip_data, gaussian_id_data, '../hex/fp32_v2/output_gaussian_id.hex')