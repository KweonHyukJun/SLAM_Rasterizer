module synopsys_cmp2
    #(
        parameter mantissa_bit = 7,
        parameter exponent_bit = 8,
        parameter precision = 16
    )
    (
        input wire clk,
        input wire rst_n,

        input wire [precision-1:0] a,
        input wire [precision-1:0] b,


        output reg [7:0] status,
        output reg [precision-1:0] z
    );



    reg [precision-1:0] a_reg;
    reg [precision-1:0] b_reg;

    wire [7:0] status_wire;

    wire [precision-1:0] min_alpha;


    wire [precision - 1:0] z0_wire;
    wire [precision - 1:0] z1_wire;


    wire [precision - 1:0] z_temp;


    assign min_alpha = (precision == 32 && mantissa_bit == 23) ? 32'h3b80_0000 :
                    (precision == 16 && mantissa_bit == 7) ? 16'h3b80 :
                    (precision == 24 && mantissa_bit == 15) ? 24'h3b80_00 :
                    {precision{1'b0}};

    // Instance of DW_fp_cmp for alpha_comp
    wire aeqb_wire, altb_wire, agtb_wire, unordered_wire;
    wire [7:0] status0_wire, status1_wire;

    DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
        alpha_comp_inst_i (
        .a(a_reg), 
        .b(b_reg), 
        .zctr(1'b0), 
        .aeqb(aeqb_wire), 
        .altb(altb_wire), 
        .agtb(agtb_wire), 
        .unordered(unordered_wire), 
        .z0(z0_wire), 
        .z1(z1_wire), 
        .status0(status0_wire), 
        .status1(status1_wire)
        );

    // Instance of DW_fp_cmp for alpha_skip_comp
    wire aeqb_skip_wire, altb_skip_wire, agtb_skip_wire, unordered_skip_wire;
    wire [7:0] status0_skip_wire, status1_skip_wire;
    wire [precision - 1:0] z1_skip_wire;

    DW_fp_cmp #(mantissa_bit, exponent_bit, 0)
        alpha_skip_comp_inst_i (
        .a(z0_wire), 
        .b(min_alpha), 
        .zctr(1'b0), 
        .aeqb(aeqb_skip_wire), 
        .altb(altb_skip_wire), 
        .agtb(agtb_skip_wire), 
        .unordered(unordered_skip_wire), 
        .z0(z_temp), 
        .z1(z1_skip_wire), 
        .status0(status0_skip_wire), 
        .status1(status1_skip_wire)
        );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            z <= '0;
            status <= '0;
            a_reg <= '0;
            b_reg <= '0;

        end
        else begin
            a_reg <= a;
            b_reg <= b;

            z <= z_temp;
            status <= status_wire;
        end
    end

endmodule