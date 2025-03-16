module synopsys_dp2
    #(
        parameter mantissa_bit = 23,
        parameter exponent_bit = 8,
        parameter precision = 32
    )
    (
        input wire clk,
        input wire rst_n,

        input wire [precision-1:0] a,
        input wire [precision-1:0] b,
        input wire [precision-1:0] c,
        input wire [precision-1:0] d,

        output reg [7:0] status,
        output reg [precision-1:0] z
    );



    reg [precision-1:0] a_reg;
    reg [precision-1:0] b_reg;
    reg [precision-1:0] c_reg;
    reg [precision-1:0] d_reg;

    wire [7:0] status_wire;


    wire [precision - 1:0] z_wire;

    wire [precision - 1:0] z_temp;


    assign z_temp = z_temp == 'h0 ? 'h0 : z_wire;

    DW_fp_dp2 #(mantissa_bit, exponent_bit, 1, 0)
        dp2_inst_i (
        .a(a_reg), 
        .b(b_reg),
        .c(c_reg),
        .d(d_reg),
        .rnd(3'b0),
        .z(z_wire), 
        .status(status_wire)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            z <= '0;
            status <= '0;
            a_reg <= '0;
            b_reg <= '0;
            c_reg <= '0;
            d_reg <= '0;
        end
        else begin
            a_reg <= a;
            b_reg <= b;
            c_reg <= c;
            d_reg <= d;

            z <= z_temp;
            status <= status_wire;
        end
    end

endmodule