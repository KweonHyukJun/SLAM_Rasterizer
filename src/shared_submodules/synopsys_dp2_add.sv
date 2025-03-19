module synopsys_dp2_add
    #(
        parameter mantissa_bit = 23,
        parameter exponent_bit = 8,
        parameter precision = 32,
        parameter ieee_compliance = 0
    )
    (
        input wire clk,
        input wire rst_n,

        input wire [precision-1:0] a,
        input wire [precision-1:0] b,
        input wire [precision-1:0] c,
        input wire [precision-1:0] d,

        input wire [precision-1:0] e,
        input wire [precision-1:0] f,
        input wire [precision-1:0] g,
        input wire [precision-1:0] h,

        output reg [precision-1:0] z
    );



    reg [precision-1:0] a_reg;
    reg [precision-1:0] b_reg;
    reg [precision-1:0] c_reg;
    reg [precision-1:0] d_reg;

    reg [precision-1:0] e_reg;
    reg [precision-1:0] f_reg;
    reg [precision-1:0] g_reg;
    reg [precision-1:0] h_reg;

    reg [precision-1:0] temp1;
    reg [precision-1:0] temp2;

    reg [precision-1:0] i_reg;
    reg [precision-1:0] j_reg;

    wire [precision-1:0] i_wire;
    wire [precision-1:0] j_wire;

    wire [7:0] status_wire [1:3];

    wire [precision-1:0] z_wire;





    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dL_dalpha_maker1 ( .a(a_reg), .b(b_reg), .c(c_reg), .d(d_reg), .rnd(3'b0), .z(i_wire), .status(status_wire[1]) );

    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dL_dalpha_maker2 ( .a(e_reg), .b(f_reg), .c(g_reg), .d(h_reg), .rnd(3'b0), .z(j_wire), .status(status_wire[2]) );


    DW_fp_add #(mantissa_bit, exponent_bit, 0)
        add_inst_i (
        .a(i_reg),
        .b(j_reg),
        .rnd(3'b0),
        .z(z_wire),
        .status(status_wire[3])
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            z <= '0;
            
            a_reg <= '0;
            b_reg <= '0;
            c_reg <= '0;
            d_reg <= '0;
            e_reg <= '0;
            f_reg <= '0;
            g_reg <= '0;
            h_reg <= '0;
            i_reg <= '0;
            j_reg <= '0;
        end
        else begin
            a_reg <= a;
            b_reg <= b;
            c_reg <= c;
            d_reg <= d;
            e_reg <= e;
            f_reg <= f;
            g_reg <= g;
            h_reg <= h;
            i_reg <= i_wire;
            j_reg <= j_wire;

            z <= z_wire;
        
        end
    end

endmodule