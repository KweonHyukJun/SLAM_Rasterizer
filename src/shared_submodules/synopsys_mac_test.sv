module synopsys_mac_test
    #(
        parameter mantissa_bit = 23,
        parameter exponent_bit = 8,
        parameter precision = 32,
        parameter ieee_compliance = 0,
        parameter synthesis_mode = 1
    )
    (
        input wire clk,
        input wire rst_n,

        input wire [precision-1:0] alpha,
        input wire [precision-1:0] gaussian_color,


        input wire valid,
        
        output reg valid2,

        output reg [precision-1:0] accum_rec2,
        output reg [precision-1:0] last_color2,
        output reg [precision-1:0] last_alpha2

    );



    reg [precision-1:0] alpha0;
    reg [precision-1:0] gaussian_color0;
    

    reg [precision-1:0] alpha1;
    reg [precision-1:0] gaussian_color1;
    
    
    reg valid0, valid1;


    reg [precision-1:0] last_alpha_mult_last_color1;
    reg [precision-1:0] One_minus_last_alpha1;


    wire [precision-1:0] last_alpha_mult_last_color1_temp;
    wire [precision-1:0] One_minus_last_alpha1_temp;

    wire [precision-1:0] last_alpha_mult_last_color1_valid_wire;
    wire [precision-1:0] last_alpha_mult_last_color1_nonvalid_wire;

    wire [precision-1:0] One_minus_last_alpha1_valid_wire;
    wire [precision-1:0] One_minus_last_alpha1_nonvalid_wire;

    wire [precision-1:0] accum_rec2_wire;
    wire [precision-1:0] accum_rec2_temp;

    wire [precision-1:0] last_alpha2_temp;
    wire [precision-1:0] last_color2_temp;
    

    wire [7:0] status_wire [1:5];

    wire [precision-1:0] One0 = (precision == 32) ? 32'h3f800000 : 16'h3f80;

    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     first_term_for_valid1 ( .a(alpha1), .b(gaussian_color1), .rnd(3'b0), .z(last_alpha_mult_last_color1_valid_wire), .status(status_wire[1]) );


    DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     first_term_for_nonvalid1 ( .a(last_alpha2), .b(last_color2), .rnd(3'b0), .z(last_alpha_mult_last_color1_nonvalid_wire), .status(status_wire[2]) );


    DW_fp_add #(mantissa_bit, exponent_bit, 0)
        one_minus_last_alpha_for_valid1 (
        .a(One0),
        .b({!alpha1[precision-1], alpha1[precision-2:0]}),
        .rnd(3'b0),
        .z(One_minus_last_alpha1_valid_wire),
        .status(status_wire[3])
    );

    DW_fp_add #(mantissa_bit, exponent_bit, 0)
        one_minus_last_alpha_for_nonvalid1 (
        .a(One0),
        .b({!last_alpha2[precision-1], last_alpha2[precision-2:0]}),
        .rnd(3'b0),
        .z(One_minus_last_alpha1_nonvalid_wire),
        .status(status_wire[4])
    );


    assign One_minus_last_alpha1_temp = valid1 ? One_minus_last_alpha1_valid_wire : One_minus_last_alpha1_nonvalid_wire;
    assign last_alpha_mult_last_color1_temp = valid1 ? last_alpha_mult_last_color1_valid_wire : last_alpha_mult_last_color1_nonvalid_wire;



    DW_fp_mac #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     second_term ( .a(accum_rec2), .b(One_minus_last_alpha1), .c(last_alpha_mult_last_color1), .rnd(3'b0), .z(accum_rec2_wire), .status(status_wire[5]) );


    assign accum_rec2_temp = valid1 ? accum_rec2_wire : accum_rec2;
    assign last_color2_temp = valid1 ? gaussian_color1 : last_color2;
    assign last_alpha2_temp = valid1 ? alpha1 : last_alpha2;



    always_ff @(posedge clk or negedge rst_n) begin
        
        if (!rst_n) begin
            alpha0 <= '0;
            alpha1 <= '0;
                        
            gaussian_color0 <= '0;
            gaussian_color1 <= '0;

            last_alpha_mult_last_color1 <= '0;
            One_minus_last_alpha1 <= '0;
            
            accum_rec2 <= '0;
            last_color2 <= '0;
            last_alpha2 <= '0;
            
            valid0 <= '0;
            valid1 <= '0;
            valid2 <= '0;
        end

        else begin

            alpha0 <= alpha;
            gaussian_color0 <= gaussian_color;
            

            alpha1 <= alpha0;
            gaussian_color1 <= gaussian_color0;
            

            last_alpha_mult_last_color1 <= last_alpha_mult_last_color1_temp;
            One_minus_last_alpha1 <= One_minus_last_alpha1_temp;

            accum_rec2 <= accum_rec2_temp;
            last_color2 <= last_color2_temp;
            last_alpha2 <= last_alpha2_temp;

            valid0 <= valid;
            valid1 <= valid0;
            valid2 <= valid1;


        end
    end

endmodule