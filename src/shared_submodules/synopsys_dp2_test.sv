module synopsys_dp2_test
    #(
        parameter mantissa_bit = 23,
        parameter exponent_bit = 8,
        parameter precision = 32,
        parameter ieee_compliance = 0
    )
    (
        input wire clk,
        input wire rst_n,

        input wire [precision-1:0] alpha,
        input wire [precision-1:0] gaussian_color,
        input wire [precision-1:0] gaussian_depth,

        input wire valid,
        
        output reg valid2,

        output reg [precision-1:0] accum_rec2,
        output reg [precision-1:0] last_color2,
        output reg [precision-1:0] last_alpha2

    );



    reg [precision-1:0] alpha0;
    reg [precision-1:0] gaussian_color0;
    reg [precision-1:0] gaussian_depth0;

    reg [precision-1:0] alpha1;
    reg [precision-1:0] gaussian_color1;
    reg [precision-1:0] gaussian_depth1;
    
    reg valid0, valid1;


    
    reg [precision-1:0] One_minus_last_alpha1;
    wire [precision-1:0] One_minus_last_alpha1_temp;

    wire [precision-1:0] One_minus_last_alpha1_valid_wire;
    wire [precision-1:0] One_minus_last_alpha1_nonvalid_wire;

    wire [precision-1:0] accum_rec2_wire;
    wire [precision-1:0] accum_rec2_temp;

    wire [7:0] status_wire [1:3];

    wire [precision-1:0] One0 = (precision == 32) ? 32'h3f800000 : 16'h3f80;

    wire [precision-1:0] last_alpha2_temp;
    wire [precision-1:0] last_color2_temp;



    // 1 - last_alpha
    // i_valid == 1일때 처리 할거
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  One_minus_last_alpha_maker_for_valid ( .a(One0), .b({!alpha1[precision-1], alpha1[precision-2:0]}), .rnd(3'b0), .z(One_minus_last_alpha1_valid_wire), .status(status_wire[1]) );

    // 1 - last_alpha
    // i_valid == 0일때 처리할 거
    DW_fp_add #(mantissa_bit, exponent_bit, 0)
	  One_minus_last_alpha_maker_for_nonvalid ( .a(One0), .b({!last_alpha2[precision-1], last_alpha2[precision-2:0]}), .rnd(3'b0), .z(One_minus_last_alpha1_nonvalid_wire), .status(status_wire[2]) );

    assign One_minus_last_alpha1_temp = valid1? One_minus_last_alpha1_valid_wire : One_minus_last_alpha1_nonvalid_wire;


    DW_fp_dp2 #(mantissa_bit, exponent_bit, ieee_compliance, 0) 
     dL_dalpha_maker1 ( .a(last_alpha2), .b(gaussian_color1), .c(gaussian_depth1), .d(gaussian_depth1), .rnd(3'b0), .z(accum_rec2_wire), .status(status_wire[3]) );


    assign last_color2_temp = valid1 ? gaussian_color1 : last_color2;
    assign last_alpha2_temp = valid1 ? alpha1 : last_alpha2;

    assign accum_rec2_temp = valid1 ? accum_rec2_wire : accum_rec2;



    always_ff @(posedge clk or negedge rst_n) begin
        
        if (!rst_n) begin
            alpha0 <= '0;
            alpha1 <= '0;
            
            
            gaussian_color0 <= '0;
            gaussian_color1 <= '0;
            
            
            gaussian_depth0 <= '0;
            gaussian_depth1 <= '0;
            

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
            gaussian_depth0 <= gaussian_depth;

            alpha1 <= alpha0;
            gaussian_color1 <= gaussian_color0;
            gaussian_depth1 <= gaussian_depth0;

            
            accum_rec2 <= accum_rec2_temp;
            last_color2 <= last_color2_temp;
            last_alpha2 <= last_alpha2_temp;

            valid0 <= valid;
            valid1 <= valid0;
            valid2 <= valid1;


        end
    end

endmodule