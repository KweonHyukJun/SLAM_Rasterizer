// Copyright (c) 2021 Sungkyunkwan University
//
// Authors:
// - Jungrae Kim <dale40@skku.edu>

module fixed_arbiter
#(
    N_MASTER                    = 4,
    DATA_SIZE                   = 32
)
(
    // input   wire                clk,
    // input   wire                rst_n,  // _n means active low

    // input interfaces
    input   wire                src_valid_i[N_MASTER-1:0],
    output  reg                 src_ready_o[N_MASTER-1:0],
    input   wire    [DATA_SIZE-1:0]     src_data_i[N_MASTER-1:0],

    input   wire                last_input_done_i[N_MASTER-1:0],
    output  reg                 last_input_done_o,

    // output interface
    output  reg                 dst_valid_o,
    // input   wire                dst_ready_i,
    output  reg     [DATA_SIZE-1:0] dst_data_o,

    input   wire                stall_backpressure,
    output  reg                 stall_from_arbiter
);
    // synopsys template
    int active_signals;

    // fixed priority arbiter
    reg other_goes_first;


    always_comb begin
        
        // default
    
        dst_valid_o             = 1'b0;
        dst_data_o              = 'h0;    // don't care
        last_input_done_o       = 1'b0;
        active_signals          = 0;
        stall_from_arbiter      = 1'b0;
        other_goes_first        = 1'b0;
        
        for (int i=0; i<N_MASTER; i++) begin
            src_ready_o[i]          = 1'b0;

            if (src_valid_i[i] || last_input_done_i[i]) begin
                active_signals = active_signals + 1;
            end
        end
        

        if (!stall_backpressure) begin
            // or use a loop
            for (int i = 0; i < N_MASTER; i++) begin
                if ((src_valid_i[i] || last_input_done_i[i]) && !other_goes_first) begin

                    if (last_input_done_i[i]) begin
                        last_input_done_o       = 1'b1;
                    end
                    
                    if (src_valid_i[i]) begin
                        dst_valid_o             = 1'b1;
                        dst_data_o              = src_data_i[i];
                        src_ready_o[i]          = 1'b1;
                        other_goes_first        = 1'b1;
                    end


                end
            end

            if (active_signals > 1) begin
                stall_from_arbiter = 1'b1;
            end

        end

    end

endmodule
