module tree_logic_wire_or
#(
    parameter input_dimensions = 16
)
(
    input wire condition_in [input_dimensions-1:0],

    output wire condition_out
);
// synopsys template 

//Sequential logic

// Wire for tree
wire condition_tree [2 * input_dimensions - 2:0];



genvar tree;
generate
    // First stage: Initialize values based on next_n_contrib_SRAM if !REB_FF
    for (tree = 0; tree < input_dimensions; tree = tree + 1) begin : tree_gen
        assign condition_tree[tree] = 
            condition_in[tree]; // Initialize with next_n_contrib_SRAM if !REB_FF
    end
    
    // Second stage and beyond: Compare values from previous stages in a tree structure
    for (tree = 0; tree < input_dimensions - 1; tree = tree + 1) begin : tree_comp
        assign condition_tree[input_dimensions + tree] = 
            (condition_tree[2 * tree] || condition_tree[2 * tree + 1]);
    end

endgenerate

// Output the final max value (root of the tree)
assign condition_out = condition_tree[2 * input_dimensions - 2]; // Final max value is at the root





// SRAM Read condition
 
endmodule