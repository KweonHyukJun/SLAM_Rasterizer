module tree_logic_wire
#(
    parameter precision = 16,
    parameter num_pixels = 16
)
(
    input wire clk,
    input wire rst_n,

    input wire REB_signal [num_pixels-1:0],

    
    input wire [precision-1:0] next_n_contrib_from_SRAM [num_pixels-1:0],

    output wire REB [num_pixels-1:0],

    output reg [precision-1:0] max_n_contrib
);

// synopsys template


localparam stage = $clog2(num_pixels);

//
logic [precision-1:0] max_n_contrib_wire;



//Sequential logic
// logic REB_FF [num_pixels-1:0];
logic [num_pixels-1:0] REB_FF;

// Wire for tree
wire [precision-1:0] max_n_contrib_tree [2 * num_pixels - 2:0];



genvar tree;
generate
    // First stage: Initialize values based on next_n_contrib_from_SRAM if !REB_FF
    for (tree = 0; tree < num_pixels; tree = tree + 1) begin : tree_gen
        assign max_n_contrib_tree[tree] = 
            (!REB_FF[tree]) ? next_n_contrib_from_SRAM[tree] : 'h0; // Initialize with next_n_contrib_from_SRAM if !REB_FF
    end
    
    // Second stage and beyond: Compare values from previous stages in a tree structure
    for (tree = 0; tree < num_pixels - 1; tree = tree + 1) begin : tree_comp
        assign max_n_contrib_tree[num_pixels + tree] = 
            (max_n_contrib_tree[2 * tree] >= max_n_contrib_tree[2 * tree + 1]) ? 
            max_n_contrib_tree[2 * tree] : max_n_contrib_tree[2 * tree + 1]; // Compare and propagate max values
    end

endgenerate

// Output the final max value (root of the tree)
assign max_n_contrib_wire = max_n_contrib_tree[2 * num_pixels - 2]; // Final max value is at the root





// SRAM Read condition
 
assign REB = REB_signal;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        max_n_contrib <= '0;
        for (int i = 0; i < num_pixels; i++) begin
            REB_FF[i] <= 1'b1;
        end
    end
    else begin

        max_n_contrib <= max_n_contrib_wire;

        for (int i = 0; i < num_pixels; i++) begin
            REB_FF[i] <= REB[i];
        end
    end
end
endmodule