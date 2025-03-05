module splatting_unit #(
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter GID_bit = 24
)
    (
    input logic clk,
    input logic rst_n,

    // 전단계 계산값
    input logic [precision-1:0]  alpha_in,

    // 컨트롤 신호
    input logic stall,
    input logic last_input,

    // 초기 Register 값 정의용
    input logic start,

    input logic [GID_bit-1:0] gaussian_id_in,
    input logic [(3 * precision)-1:0] gaussian_color, // | R | G | B |
    input logic [precision-1:0] gaussian_depth,

    input logic i_valid, // !skip signal

    input logic [11:0] n_contrib_in,

    // 출력
    output logic [GID_bit-1:0] gaussian_id_out,
    output logic [(3 * precision)-1:0] pixel_color,
    output logic [precision-1:0] pixel_depth,

    output logic [11:0] n_contrib_out, // 얘는 여기서 세면 안될듯?
    output logic [precision-1:0] pixel_opacity,
    output logic [precision-1:0] T_first,
    output logic pixel_valid_out

    // 진행중인 signal 필요시 started && !last_input 형태로?

);
// synopsys template

// Register declaration
logic [precision-1:0] alpha0, alpha1;
logic i_valid0, i_valid1;

logic [GID_bit-1:0] gaussian_id0, gaussian_id1;
logic [precision-1:0] T_mult_alpha1;

logic last_input0, last_input1;

logic [(3*precision)-1:0] gaussian_color0, gaussian_color1;
logic [precision-1:0] gaussian_depth0, gaussian_depth1;

logic [11:0] n_contrib0, n_contrib1;

logic should_be_finished;

// Wire declaration
logic [precision-1:0] One;
logic [precision-1:0] T_escape_threshold;
logic [precision-1:0] One_minus_alpha_temp;

logic [precision-1:0] T1_temp, T1_next;
logic [precision-1:0] T_mult_alpha1_temp, T_mult_alpha1_calc;
logic [precision-1:0] opacity_temp, opacity_calc;

logic [precision-1:0] pixel_depth1_temp, pixel_depth1_calc;
logic [(3*precision)-1:0] pixel_color1_temp, pixel_color1_calc;
logic T_escape_result;
logic transmittance_done_temp;
logic [7:0] status_flag[0:1];

logic [precision-1:0] not_used_z0, not_used_z1;
logic aeqb_inst, agtb_inst, unordered_inst;
logic [7:0] status_inst [1:8];


localparam ieee_compliance = 1'b0;

assign One = (precision == 32 && mantissa_bit == 23) ? 32'h3f80_0000 :
                (precision == 16 && mantissa_bit == 7) ? 16'h3f80 :
                (precision == 24 && mantissa_bit == 15) ? 24'h3f80_00 :
                {precision{1'b0}};


assign T_escape_threshold = (precision == 32 && mantissa_bit == 23) ? 32'h38d1_b717 :
                (precision == 16 && mantissa_bit == 7) ? 16'h38d1 :
                (precision == 24 && mantissa_bit == 15) ? 24'h38d1_b7 :
                {precision{1'b0}};  

////////////////////////////////////////////////////////////////////
//////////////////////////// Clock Step 0 //////////////////////////
////////////////////////////////////////////////////////////////////

DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
 T_mult_alpha_maker ( .a(T_first), .b(alpha0), .rnd(3'b0), .z(T_mult_alpha1_calc), .status(status_inst[3]) );


DW_fp_add #(mantissa_bit, exponent_bit, 0)
 One_minus_alpha_adder ( .a(One), .b({!alpha0[precision-1], alpha0[precision-2:0]}), .rnd(3'b0), .z(One_minus_alpha_temp), .status(status_inst[1]) );

DW_fp_mult #(mantissa_bit, exponent_bit, ieee_compliance, 0)
 next_T_maker ( .a(T_first), .b(One_minus_alpha_temp), .rnd(3'b0), .z(T1_next), .status(status_inst[2]) );

 // T 이용한 escape 조건
DW_fp_cmp #(mantissa_bit, exponent_bit, ieee_compliance, 0)
 T_escape_condition ( .a(T1_next), .b(T_escape_threshold),
            .zctr(1'b0), 
            .aeqb(aeqb_inst), 
            .altb(T_escape_result), 
            .agtb(agtb_inst), 
            .unordered(unordered_inst), 
            .z0(not_used_z0), 
            .z1(not_used_z1), 
            .status0(status_flag[0]), 
            .status1(status_flag[1]));



DW_fp_add #(mantissa_bit, exponent_bit, 0)
 opacity_maker ( .a(One), .b({!T_first[precision-1], T_first[precision-2:0]}), .rnd(3'b0), .z(opacity_calc), .status(status_inst[4]) );



assign opacity_temp = i_valid0 && !should_be_finished ? opacity_calc : pixel_opacity;

assign T1_temp = (i_valid0 && !T_escape_result) && !should_be_finished ? T1_next : T_first;

assign T_mult_alpha1_temp = i_valid0 ? T_mult_alpha1_calc : T_mult_alpha1;

assign transmittance_done_temp = (i_valid0 && T_escape_result) || last_input0;

////////////////////////////////////////////////////////////////////
//////////////////////////// Clock Step 1 //////////////////////////
////////////////////////////////////////////////////////////////////


// assign n_contrib_temp = (i_valid1 && !T_escape_result) && !should_be_finished ? n_contrib + 'd1 : n_contrib;


DW_fp_mac #(mantissa_bit, exponent_bit, ieee_compliance, 0)
 pixel_color_R_maker ( .a(T_mult_alpha1), .b(gaussian_color1[(3*precision)-1:2*precision]), .c(pixel_color[(3*precision)-1:2*precision]), .rnd(3'b0), .z(pixel_color1_calc[(3*precision)-1:2*precision]), .status(status_inst[5]) );

DW_fp_mac #(mantissa_bit, exponent_bit, ieee_compliance, 0)
 pixel_color_G_maker ( .a(T_mult_alpha1), .b(gaussian_color1[(2*precision)-1:precision]), .c(pixel_color[(2*precision)-1:precision]), .rnd(3'b0), .z(pixel_color1_calc[(2*precision)-1:precision]), .status(status_inst[6]) );

DW_fp_mac #(mantissa_bit, exponent_bit, ieee_compliance, 0)
 pixel_color_B_maker ( .a(T_mult_alpha1), .b(gaussian_color1[precision-1:0]), .c(pixel_color[precision-1:0]), .rnd(3'b0), .z(pixel_color1_calc[precision-1:0]), .status(status_inst[7]) );

DW_fp_mac #(mantissa_bit, exponent_bit, ieee_compliance, 0)
 pixel_depth_maker ( .a(T_mult_alpha1), .b(gaussian_depth1), .c(pixel_depth), .rnd(3'b0), .z(pixel_depth1_calc), .status(status_inst[8]) );


assign pixel_color1_temp = i_valid1 && !should_be_finished ? pixel_color1_calc : pixel_color;
assign pixel_depth1_temp = i_valid1 && !should_be_finished ? pixel_depth1_calc : pixel_depth;



always_ff @ (posedge clk) begin
    if (!rst_n) begin
        gaussian_id_out <= '0;
        pixel_color <= '0;
        pixel_depth <= '0;
        n_contrib_out <= '0;
        pixel_opacity <= '0;
        T_first <= '0;
        pixel_valid_out <= '0;
        alpha0 <= '0;
        alpha1 <= '0;
        gaussian_id0 <= '0;
        gaussian_id1 <= '0;
        T_mult_alpha1 <= '0;
        i_valid0 <= '0;
        i_valid1 <= '0;
        last_input0 <= '0;
        last_input1 <= '0;

        gaussian_color0 <= '0;
        gaussian_color1 <= '0;


        gaussian_depth0 <= '0;
        gaussian_depth1 <= '0;

        should_be_finished <= 1'b0;

        n_contrib0 <= '0;
        n_contrib1 <= '0;

    end

    else begin
        // start와 stall 분리, start가 유사 reset 기능

        if (start) begin
            T_first <= One;
            alpha0 <= 'h0;
            alpha1 <= 'h0;
            T_mult_alpha1 <= 'h0;
            pixel_color <= 'h0;
            pixel_depth <= 'h0;
            pixel_opacity <= 'h0;
            // pixel_valid_out <= 'h0;
            should_be_finished <= 1'b0;
            n_contrib0 <= 'h0;
            n_contrib1 <= 'h0;
            n_contrib_out <= 'h0;

            pixel_valid_out <= 1'b0;

            gaussian_id_out <= '0;
            // pixel_color <= '0;
            // pixel_depth <= '0;
            // n_contrib_out <= '0;
            // pixel_opacity <= '0;
            // T_first <= '0;
            // pixel_valid_out <= '0;
            
            alpha0 <= '0;
            alpha1 <= '0;
            gaussian_id0 <= '0;
            gaussian_id1 <= '0;
            // T_mult_alpha1 <= '0;
            i_valid0 <= '0;
            i_valid1 <= '0;
            last_input0 <= '0;
            last_input1 <= '0;

            gaussian_color0 <= '0;
            gaussian_color1 <= '0;


            gaussian_depth0 <= '0;
            gaussian_depth1 <= '0;

            // should_be_finished <= 1'b0;

            // n_contrib0 <= '0;
            // n_contrib1 <= '0;

        end        
        

        else begin
            if (!stall) begin

                // if (start) begin
                //     T_first <= One;
                //     alpha0 <= 'h0;
                //     alpha1 <= 'h0;
                //     T_mult_alpha1 <= 'h0;
                //     pixel_color <= 'h0;
                //     pixel_depth <= 'h0;
                //     pixel_opacity <= 'h0;
                //     pixel_valid_out <= 'h0;
                //     should_be_finished <= 1'b0;
                //     n_contrib0 <= 'h0;
                //     n_contrib1 <= 'h0;
                //     n_contrib_out <= 'h0;

                //     pixel_valid_out <= 1'b0;
                // end

                // else begin
                //     T_first <= T1_temp;
                //     alpha0 <= alpha_in;
                //     alpha1 <= alpha0;
                //     T_mult_alpha1 <= T_mult_alpha1_temp;
                //     pixel_color <= pixel_color1_temp;
                //     pixel_depth <= pixel_depth1_temp;
                //     pixel_opacity <= opacity_temp;                

                //     pixel_valid_out <= transmittance_done_temp || should_be_finished;
                // end



                T_first <= T1_temp;
                alpha0 <= alpha_in;
                alpha1 <= alpha0;
                T_mult_alpha1 <= T_mult_alpha1_temp;
                pixel_color <= pixel_color1_temp;
                pixel_depth <= pixel_depth1_temp;
                pixel_opacity <= opacity_temp;                

                pixel_valid_out <= transmittance_done_temp || should_be_finished;



                if (transmittance_done_temp) begin
                    should_be_finished <= 1'b1;


                end

                if (!should_be_finished) begin
                    n_contrib_out <= n_contrib1;
                end

                last_input0 <= last_input;
                last_input1 <= last_input0;

                gaussian_id_out <= gaussian_id1;
                gaussian_id1 <= gaussian_id0;
                gaussian_id0 <= gaussian_id_in;

                
                gaussian_color1 <= gaussian_color0;
                gaussian_color0 <= gaussian_color;

                gaussian_depth1 <= gaussian_depth0;
                gaussian_depth0 <= gaussian_depth;  

                i_valid0 <= i_valid;
                i_valid1 <= i_valid0;

                n_contrib0 <= n_contrib_in;
                n_contrib1 <= n_contrib0;


            end

        end
    end

end


endmodule    