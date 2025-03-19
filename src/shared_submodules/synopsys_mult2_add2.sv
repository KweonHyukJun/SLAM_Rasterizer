module synopsys_mult2_add2
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

    reg [precision-1:0] i_reg;
    reg [precision-1:0] j_reg;
    reg [precision-1:0] k_reg;
    reg [precision-1:0] l_reg;

    reg [precision-1:0] m_reg;
    reg [precision-1:0] n_reg;

    wire [precision-1:0] i_wire;
    wire [precision-1:0] j_wire;
    wire [precision-1:0] k_wire;
    wire [precision-1:0] l_wire;
    wire [precision-1:0] m_wire;
    wire [precision-1:0] n_wire;

    wire [7:0] status_wire [1:7];

    wire [precision-1:0] z_wire;

    DW_fp_mult #(mantissa_bit, exponent_bit, 1, 0)
        mult2_inst_1 (
        .a(a_reg), 
        .b(b_reg),
        .rnd(3'b0),
        .z(i_wire), 
        .status(status_wire[1])
    );

    DW_fp_mult #(mantissa_bit, exponent_bit, 1, 0)
        mult2_inst_2 (
        .a(c_reg), 
        .b(d_reg),
        .rnd(3'b0),
        .z(j_wire), 
        .status(status_wire[2])
    );

    DW_fp_mult #(mantissa_bit, exponent_bit, 1, 0)
        mult2_inst_3 (
        .a(e_reg), 
        .b(f_reg),
        .rnd(3'b0),
        .z(k_wire), 
        .status(status_wire[3])
    );

    DW_fp_mult #(mantissa_bit, exponent_bit, 1, 0)
        mult2_inst_4 (
        .a(g_reg), 
        .b(h_reg),
        .rnd(3'b0),
        .z(l_wire), 
        .status(status_wire[4])
    );


    DW_fp_add #(mantissa_bit, exponent_bit, 0)
        add_inst_1 (
        .a(i_reg),
        .b(j_reg),
        .rnd(3'b0),
        .z(m_wire),
        .status(status_wire[5])
    );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
        add_inst_2 (
        .a(k_reg),
        .b(l_reg),
        .rnd(3'b0),
        .z(n_wire),
        .status(status_wire[6])
    );

    
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
        add_inst_3 (
        .a(m_reg),
        .b(n_reg),
        .rnd(3'b0),
        .z(z_wire),
        .status(status_wire[7])
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
            k_reg <= '0;
            l_reg <= '0;
            m_reg <= '0;
            n_reg <= '0;
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
            k_reg <= k_wire;
            l_reg <= l_wire;
            m_reg <= m_wire;
            n_reg <= n_wire;

            z <= z_wire;
        end
    end

endmodule