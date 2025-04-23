module tree_logic_test1
#(
    parameter Banks = 16,
    parameter Encoder_outs = 4
)
(
    input wire last_input_done_from_encoder_out [Banks * Encoder_outs-1:0],

    output wire last_input_done_to_4x_fifo_valid_comb [Banks-1:0]
);


//Sequential logic

// Wire for tree
// logic last_input_done_from_encoder_out [Banks * Encoder_outs-1:0];
// logic last_input_done_to_4x_fifo_valid_comb [Banks-1:0];


genvar Bnk;
generate 
    for (Bnk = 0; Bnk < Banks; Bnk = Bnk + 1) begin : stall_from_encoder_tree_logic_wire_gen
        tree_logic_wire_or #(
            .input_dimensions(Encoder_outs)
        )
        last_input_done_to_4x_fifo_valid_tree_logic_wire (
            .stall_condition_in(last_input_done_from_encoder_out[Bnk * Encoder_outs +: Encoder_outs]),
            .stall_condition_out(last_input_done_to_4x_fifo_valid_comb[Bnk])
        );
    end
endgenerate



endmodule