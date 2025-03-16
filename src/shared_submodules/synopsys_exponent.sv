module synopsys_exponent
    #(
        parameter mantissa_bit = 23,
        parameter exponent_bit = 8,
        parameter precision = 32
    )
    (
        input wire clk,
        input wire rst_n,

        input wire [precision-1:0] a,

        output reg [7:0] status,
        output reg [precision-1:0] z
    );



    reg [precision-1:0] a_reg;
    wire [7:0] status_wire;


    wire [precision - 1:0] z_wire;


    DW_fp_exp #(mantissa_bit, exponent_bit, 1, 0)
        exponent_power_inst_i (
        .a(a_reg), 
        .z(z_wire), 
        .status(status_wire)
        );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            z <= '0;
            status <= '0;
            a_reg <= '0;
        end
        else begin
            a_reg <= a;
            z <= z_wire;
            status <= status_wire;
        end
    end

endmodule