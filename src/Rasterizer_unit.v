//////////////////////////////////////////////////////////////////////////////////
// Company: Sungkyunkwan Univ. IDS LAB  
// Engineer: Kweon Hyuk Jun 
// 
// Create Date: 2024/08/23 18:02:07
// Design Name: Rasterizer
// Module Name: Rasterizer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// One Unit for One pixel
module Rasterizer_unit
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 7,
        parameter precision = 16,
        parameter inputs = 1
    )
(
    //reset and clock
    input wire clk,
    input wire rst_n,
    
    input wire done, // pixel worker group controller에서 일하는 여부를 내려준다고 가정 (last contributor 이런것도 포함)

    input wire [11:0] W, 
    input wire [11:0] H,

    input wire i_valid,
    input wire stall,

    input wire [15:0] block_id , // block index x at [0] y at [1]  // 1920 이 16x16 으로 분해시 120이니까 최대 비트 7개면 가능 (32비트 쓰지말고)
    
    // input wire [(3 * precision) - 1 : 0] background_color, //fp32 | R | G | B |

    input wire [(2 * precision) - 1:0] mean2D, //fp32 | X | Y | 
    input wire [(4 * precision) - 1:0] conic_opacity, // fp32 | X | Y | Z | W |

    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id,

    input wire [31:0] gaussian_id,

    input wire [(3 * precision) - 1:0] gaussian_color, //fp32 | R | G | B |
    input wire [precision - 1 : 0] gaussian_depth, //fp32

    input wire [(3 * precision) - 1:0] dL_dpixel, //fp32 | R | G | B |
    input wire [precision - 1:0] dL_dpixel_depth, //fp32

    input wire [precision - 1:0] T_first,
    input wire T_first_valid,


    output reg [(2 * precision) - 1:0] dL_dmean2D_out, // fp32 | X | Y |
    output reg [(4 * precision) - 1:0] dL_dconic_out, // fp32 | X | Y | Z | W |
    output reg [precision - 1:0] dL_dopacity_out, // fp32 
    output reg [(3 * precision) - 1:0] dL_dcolor_out, // fp32 | R | G | B |
    output reg [precision - 1:0] dL_ddepth_out, // fp32

    output reg gradient_valid
    // output reg skip
    );

    localparam stage1_latency = 7;
    localparam stage2_latency = 9;
    // gaussian ID 기록해서 Gradient 계산 후 반환해야함

    // | ---------------->>>> forward path  ---------------->>>> |
    // | <<<<---------------- backward path <<<<---------------- |
    //         | (next)
    //             | (current)
    
    // FF register
    // 초기값을 2번째에 넘기려면 필요함 
    // T_final, gaussian color, id , depth, dL_dpixel, dL_dpixel_depth 등등...
    // 몇 사이클을 쉬어야 할까

    reg [precision - 1:0] T_first0, T_first1, T_first2, T_first3, T_first4, T_first5, T_first6, T_first7;
    reg T_first_valid0, T_first_valid1, T_first_valid2, T_first_valid3, T_first_valid4, T_first_valid5, T_first_valid6, T_first_valid7;
    reg [precision - 1:0] gaussian_depth0, gaussian_depth1, gaussian_depth2, gaussian_depth3, gaussian_depth4, gaussian_depth5, gaussian_depth6, gaussian_depth7;
    reg [(3 * precision) - 1:0] gaussian_color0, gaussian_color1, gaussian_color2, gaussian_color3, gaussian_color4, gaussian_color5, gaussian_color6, gaussian_color7;
    reg [31:0] gaussian_id0, gaussian_id1, gaussian_id2, gaussian_id3, gaussian_id4, gaussian_id5, gaussian_id6, gaussian_id7;
    reg [(3 * precision) - 1:0] dL_dpixel0, dL_dpixel1, dL_dpixel2, dL_dpixel3, dL_dpixel4, dL_dpixel5, dL_dpixel6, dL_dpixel7;
    reg [precision - 1:0] dL_dpixel_depth0, dL_dpixel_depth1, dL_dpixel_depth2, dL_dpixel_depth3, dL_dpixel_depth4, dL_dpixel_depth5, dL_dpixel_depth6, dL_dpixel_depth7;
    reg early_skip6, early_skip7;


    wire [precision - 1:0] G_wire;
    wire [(2 * precision) - 1:0] d_wire;
    wire [precision - 1:0] alpha_wire;
    wire skip_wire;
    wire [(4 * precision) - 1:0] conic_opacity_wire;
    wire skip_and_alpha_done_and_total_gradient_valid;


    wire [(3 * precision) - 1:0] dL_dcolor_wire;
    wire [precision - 1:0] dL_ddepth_wire, dL_dopacity_wire;
    wire [(2 * precision) - 1:0] dL_dmean2D_wire;
    wire [(4 * precision) - 1:0] dL_dconic_wire;
    wire gradient_valid_out;
    wire early_skip_from_stage1;

    //skip and alpha module
    // Phase 1 alpha and skip Logic
    skip_unit #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision), .inputs(inputs)) 
    skip_unit_stage1 (.clk(clk), .rst_n(rst_n), .block_id(block_id), .mean2D(mean2D), .conic_opacity(conic_opacity), .pixel_id(pixel_id), .i_valid(i_valid), .early_skip(early_skip_from_stage1), // stage 5에서 나옴

    .skip_out(skip_wire), .G_out(G_wire), .d_out(d_wire), .alpha_out(alpha_wire), .conic_opacity_out(conic_opacity_wire),
    .skip_and_alpha_done_out(skip_and_alpha_done_and_total_gradient_valid)

    );


    // Phase 2, Skip distribution and 


    // Phase 3, Gradient Logic
    // background 추가 처리 필요 (이거를 있다고 해야되나)
    gradient_unit #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision)) 
    gradient_unit_stage2 (.clk(clk), .rst_n(rst_n), .W(W), .H(H), .G(G_wire), .d(d_wire), .conic_opacity(conic_opacity_wire), .alpha_in(alpha_wire),
    .T_first(T_first6), .T_first_valid(T_first_valid6), .gaussian_color(gaussian_color6), .gaussian_depth(gaussian_depth6), 

    .i_valid(skip_and_alpha_done_and_total_gradient_valid && !skip_wire),
    .dL_dpixel(dL_dpixel), .dL_dpixel_depth(dL_dpixel_depth),
    .stall(stall)

    .dL_dcolor(dL_dcolor_wire), .dL_ddepth(dL_ddepth_wire), .dL_dmean2D(dL_dmean2D_wire), .dL_dconic(dL_dconic_wire), .dL_dopacity(dL_dopacity_wire),
    .gradient_valid_out(gradient_valid_out)
    );

    // clock
    always @ (posedge clk) begin
        if (!rst_n) begin
            // Reset Output Registers
            dL_dmean2D_out <= 'h0;
            dL_dconic_out <= 'h0;
            dL_dopacity_out <= 'h0;
            dL_dcolor_out <= 'h0;
            dL_ddepth_out <= 'h0;

            gradient_valid <= 1'b0;
            // skip <= 1'b0;

            // Reset Internal Registers (T_first, Gaussian, etc.)
            T_first0 <= 'h0; T_first1 <= 'h0; T_first2 <= 'h0; T_first3 <= 'h0;
            T_first4 <= 'h0; T_first5 <= 'h0; T_first6 <= 'h0; T_first7 <= 'h0;

            T_first_valid0 <= 1'b0; T_first_valid1 <= 1'b0;
            T_first_valid2 <= 1'b0; T_first_valid3 <= 1'b0;
            T_first_valid4 <= 1'b0; T_first_valid5 <= 1'b0;
            T_first_valid6 <= 1'b0; T_first_valid7 <= 1'b0;

            gaussian_depth0 <= 'h0; gaussian_depth1 <= 'h0;
            gaussian_depth2 <= 'h0; gaussian_depth3 <= 'h0;
            gaussian_depth4 <= 'h0; gaussian_depth5 <= 'h0;
            gaussian_depth6 <= 'h0; gaussian_depth7 <= 'h0;

            gaussian_color0 <= 'h0; gaussian_color1 <= 'h0;
            gaussian_color2 <= 'h0; gaussian_color3 <= 'h0;
            gaussian_color4 <= 'h0; gaussian_color5 <= 'h0;
            gaussian_color6 <= 'h0; gaussian_color7 <= 'h0;

            gaussian_id0 <= 'h0; gaussian_id1 <= 'h0;
            gaussian_id2 <= 'h0; gaussian_id3 <= 'h0;
            gaussian_id4 <= 'h0; gaussian_id5 <= 'h0;
            gaussian_id6 <= 'h0; gaussian_id7 <= 'h0;

            dL_dpixel0 <= 'h0; dL_dpixel1 <= 'h0;
            dL_dpixel2 <= 'h0; dL_dpixel3 <= 'h0;
            dL_dpixel4 <= 'h0; dL_dpixel5 <= 'h0;
            dL_dpixel6 <= 'h0; dL_dpixel7 <= 'h0;

            dL_dpixel_depth0 <= 'h0; dL_dpixel_depth1 <= 'h0;
            dL_dpixel_depth2 <= 'h0; dL_dpixel_depth3 <= 'h0;
            dL_dpixel_depth4 <= 'h0; dL_dpixel_depth5 <= 'h0;
            dL_dpixel_depth6 <= 'h0; dL_dpixel_depth7 <= 'h0;

            early_skip6 <= 'b0; early_skip7 <= 'b0;
        end

        else begin
            // if (!stall) begin
            ////////////////////////////////////////////////////////////////////
            ///////////////////////// Clock 1 Data Input ///////////////////////
            ////////////////////////////////////////////////////////////////////

            T_first0 <= T_first;
            T_first_valid0 <= T_first_valid;
            gaussian_color0 <= gaussian_color;
            gaussian_depth0 <= gaussian_depth;
            gaussian_id0 <= gaussian_id;
            dL_dpixel0 <= dL_dpixel;
            dL_dpixel_depth0 <= dL_dpixel_depth;

            ////////////////////////////////////////////////////////////////////
            ///////////////////////// Clock 2 Data Input ///////////////////////
            ////////////////////////////////////////////////////////////////////

            T_first1 <= T_first0;
            T_first_valid1 <= T_first_valid0;
            gaussian_color1 <= gaussian_color0;
            gaussian_depth1 <= gaussian_depth0;
            gaussian_id1 <= gaussian_id0;
            dL_dpixel1 <= dL_dpixel0;
            dL_dpixel_depth1 <= dL_dpixel_depth0;

            ////////////////////////////////////////////////////////////////////
            ///////////////////////// Clock 3 Data Input ///////////////////////
            ////////////////////////////////////////////////////////////////////

            T_first2 <= T_first1;
            T_first_valid2 <= T_first_valid1;
            gaussian_color2 <= gaussian_color1;
            gaussian_depth2 <= gaussian_depth1;
            gaussian_id2 <= gaussian_id1;
            dL_dpixel2 <= dL_dpixel1;
            dL_dpixel_depth2 <= dL_dpixel_depth1;

            ////////////////////////////////////////////////////////////////////
            ///////////////////////// Clock 4 Data Input ///////////////////////
            ////////////////////////////////////////////////////////////////////

            T_first3 <= T_first2;
            T_first_valid3 <= T_first_valid2;
            gaussian_color3 <= gaussian_color2;
            gaussian_depth3 <= gaussian_depth2;
            gaussian_id3 <= gaussian_id2;
            dL_dpixel3 <= dL_dpixel2;
            dL_dpixel_depth3 <= dL_dpixel_depth2;

            ////////////////////////////////////////////////////////////////////
            ///////////////////////// Clock 5 Data Input ///////////////////////
            ////////////////////////////////////////////////////////////////////

            T_first4 <= T_first3;
            T_first_valid4 <= T_first_valid3;
            gaussian_color4 <= gaussian_color3;
            gaussian_depth4 <= gaussian_depth3;
            gaussian_id4 <= gaussian_id3;
            dL_dpixel4 <= dL_dpixel3;
            dL_dpixel_depth4 <= dL_dpixel_depth3;

            ////////////////////////////////////////////////////////////////////
            ///////////////////////// Clock 6 Data Input ///////////////////////
            ////////////////////////////////////////////////////////////////////

            T_first5 <= T_first4;
            T_first_valid5 <= T_first_valid4;
            gaussian_color5 <= gaussian_color4;
            gaussian_depth5 <= gaussian_depth4;
            gaussian_id5 <= gaussian_id4;
            dL_dpixel5 <= dL_dpixel4;
            dL_dpixel_depth5 <= dL_dpixel_depth4;

            ////////////////////////////////////////////////////////////////////
            ///////////////////////// Clock 7 Data Input ///////////////////////
            ////////////////////////////////////////////////////////////////////

            T_first6 <= T_first5;
            T_first_valid6 <= T_first_valid5;
            gaussian_color6 <= gaussian_color5;
            gaussian_depth6 <= gaussian_depth5;
            gaussian_id6 <= gaussian_id5;
            dL_dpixel6 <= dL_dpixel5;
            dL_dpixel_depth6 <= dL_dpixel_depth5;

            early_skip6 <= early_skip_from_stage1;

            ////////////////////////////////////////////////////////////////////
            ///////////////////////// Clock 8 Data Input ///////////////////////
            ////////////////////////////////////////////////////////////////////

            T_first7 <= T_first6;
            T_first_valid7 <= T_first_valid6;
            gaussian_color7 <= gaussian_color6;
            gaussian_depth7 <= gaussian_depth6;
            gaussian_id7 <= gaussian_id6;
            dL_dpixel7 <= dL_dpixel6;
            dL_dpixel_depth7 <= dL_dpixel_depth6;

            early_skip7 <= early_skip6;



            ////////////////////////////////////////////////////////////////////
            ///////////////////// Clock 17 Final Data output ///////////////////
            ////////////////////////////////////////////////////////////////////

            dL_dcolor_out <= dL_dcolor_wire;
            dL_ddepth_out <= dL_ddepth_wire;
            dL_dmean2D_out <= dL_dmean2D_wire;
            dL_dconic_out <= dL_dconic_wire;
            dL_dopacity_out <= dL_dopacity_wire;
            gradient_valid <= gradient_valid_out;

        end

    end

endmodule