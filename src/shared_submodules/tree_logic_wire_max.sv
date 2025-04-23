module tree_logic_wire_max
#(
    parameter GID_bit = 16,
    parameter num_pixels = 16
)
(
    input wire REB_signal [num_pixels-1:0],

    input wire [GID_bit-1:0] value_in [num_pixels-1:0],

    output wire [GID_bit-1:0] max_value_out
);

// synopsys template


localparam stage = $clog2(num_pixels);

//

wire [GID_bit-1:0] max_value_tree [2 * num_pixels - 2:0];


genvar tree;
generate
    // First stage: Initialize values based on value_in if !REB_FF
    for (tree = 0; tree < num_pixels; tree = tree + 1) begin : tree_gen
        assign max_value_tree[tree] = 
            (!REB_signal[tree]) ? value_in[tree] : 'h0; // Initialize with value_in if !REB_FF
    end
    
    // Second stage and beyond: Compare values from previous stages in a tree structure
    for (tree = 0; tree < num_pixels - 1; tree = tree + 1) begin : tree_comp
        assign max_value_tree[num_pixels + tree] = 
            (max_value_tree[2 * tree] >= max_value_tree[2 * tree + 1]) ? 
            max_value_tree[2 * tree] : max_value_tree[2 * tree + 1]; // Compare and propagate max values
    end

endgenerate

// Output the final max value (root of the tree)
assign max_value_out = max_value_tree[2 * num_pixels - 2]; // Final max value is at the root


endmodule