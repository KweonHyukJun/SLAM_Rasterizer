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


localparam stage = $clog2(num_pixels);

//
logic [precision-1:0] max_n_contrib_wire;



//Sequential logic
// logic REB_FF [num_pixels-1:0];
logic [num_pixels-1:0] REB_FF;


// Wire for tree
wire [precision-1:0] max_n_contrib_tree [num_pixels - 1:0];


// genvar k;
// generate 
//     for (k = 0; k < num_pixels; k++) begin : max_n_contrib_tree_gen
//         assign max_n_contrib_tree[k] = !REB_FF[k] ? next_n_contrib_from_SRAM[k] : '0;
//     end
// endgenerate




genvar tree, stages;
generate
    // First stage: Compare adjacent pairs of pixels
    for (stages = 0; stages < stage; stages = stages + 1) begin : stage_gen
        for (tree = 0; tree < num_pixels / (2 ** (stages + 1)); tree = tree + 1) begin : tree_gen

            assign max_n_contrib_tree[tree] = (stages == 0) ? 

                (REB_FF[tree] && REB_FF[tree+1] ? next_n_contrib_from_SRAM[tree] : next_n_contrib_from_SRAM[tree+1]) 

                : (max_n_contrib_tree[tree*2] > max_n_contrib_tree[tree*2+1] ? max_n_contrib_tree[tree*2] : max_n_contrib_tree[tree*2+1]);


        end
    end
endgenerate

assign max_n_contrib_wire = max_n_contrib_tree[0];


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