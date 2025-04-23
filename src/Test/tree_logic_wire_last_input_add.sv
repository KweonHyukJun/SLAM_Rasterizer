module tree_logic_wire_last_input_add
#(
    parameter input_dimensions = 16
)
(
    input wire last_input_done [input_dimensions-1:0],

    output wire [$clog2(input_dimensions):0] last_input_done_out
);


//Sequential logic

// Wire for tree
wire [$clog2(input_dimensions):0] last_input_done_tree [2 * input_dimensions - 2:0];



genvar tree;
generate
    // First stage: Initialize values based on next_n_contrib_from_SRAM if !REB_FF
    for (tree = 0; tree < input_dimensions; tree = tree + 1) begin : tree_gen
        assign last_input_done_tree[tree] = 
            last_input_done[tree]; // Initialize with next_n_contrib_from_SRAM if !REB_FF
    end
    
    // Second stage and beyond: Compare values from previous stages in a tree structure
    for (tree = 0; tree < input_dimensions - 1; tree = tree + 1) begin : tree_comp
        assign last_input_done_tree[input_dimensions + tree] = 
            (last_input_done_tree[2 * tree] + last_input_done_tree[2 * tree + 1]);
    end

endgenerate


assign last_input_done_out = last_input_done_tree[2 * input_dimensions - 2]; // Final max value is at the root

 
endmodule