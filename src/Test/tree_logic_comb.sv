module tree_logic_comb 
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


//Combinatinol logic
logic [precision-1:0] max_n_contrib_wire;


//Sequential logic
logic REB_FF [num_pixels-1:0];



always_comb begin
    max_n_contrib_wire = '0;

    for (int i = 0; i < num_pixels; i++) begin
        if (!REB_FF[i] && next_n_contrib_from_SRAM[i] > max_n_contrib_wire) begin
            max_n_contrib_wire = next_n_contrib_from_SRAM[i];
        end
    end
end

genvar k;
generate
    for (k = 0; k < num_pixels; k++) begin : REB_gen
        assign REB[k] = REB_signal[k];
    end
endgenerate




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