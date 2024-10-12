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
        parameter precision = 16
    )
(
    //reset and clock
    input wire clk,
    input wire rst_n,
    
    input wire done, // pixel worker group controller에서 일하는 여부를 내려준다고 가정 (last contributor 이런것도 포함)

    input wire [11:0] W, // int 할 필요가? 1920이라 쳐도 2^11
    input wire [11:0] H,

    input wire i_valid,
    // input wire stall,

    // input wire [63:0] block_id , // block index x at [0] y at [1]  // 1920 이 16x16 으로 분해시 120이니까 최대 비트 7개면 가능 (32비트 쓰지말고)
    input wire [15:0] block_id , // block index x at [0] y at [1]  // 1920 이 16x16 으로 분해시 120이니까 최대 비트 7개면 가능 (32비트 쓰지말고)
    
    // input wire [(3 * precision) - 1 : 0] background_color, //fp32 | R | G | B |

    input wire [(2 * precision) - 1:0] mean2D, //fp32 | X | Y | 
    input wire [(4 * precision) - 1:0] conic_opacity, // fp32 | X | Y | Z | W |

    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id,

    // input wire [31:0] gaussian_id,
    input wire [(3 * precision) - 1:0] gaussian_color, //fp32 | R | G | B |
    input wire [precision - 1 : 0] gaussian_depth, //fp32

    input wire [(3 * precision) - 1:0] dL_dpixel, //fp32 | R | G | B |
    input wire [precision - 1:0] dL_dpixel_depth, //fp32


    output reg [(2 * precision) - 1:0] dL_dmean2D, // fp32 | X | Y |
    output reg [(4 * precision) - 1:0] dL_dconic, // fp32 | X | Y | Z | W |
    output reg [precision - 1:0] dL_dopacity, // fp32 
    output reg [(3 * precision) - 1:0] dL_dcolor, // fp32 | R | G | B |
    output reg [precision - 1:0] dL_ddepth, // fp32

    output reg gradient_valid_out,
    output reg skip
    
    );

    // gaussian ID 기록해서 Gradient 계산 후 반환해야함

    // | ---------------->>>> forward path  ---------------->>>> |
    // | <<<<---------------- backward path <<<<---------------- |
    //         | (next)
    //             | (current)
    
    // FF register
    // 두개가 필요한가 ? (합성 후 테스트)

    
    reg [precision - 1 : 0] T_reg; 
    reg [(3 * precision) - 1 : 0] color_reg;
    reg [precision - 1 : 0] depth_reg;
    reg [precision - 1 : 0] alpha_reg;

    reg [(3 * precision) - 1 : 0] accum_rec_reg;
    reg [precision - 1 : 0] accum_rec_depth_reg;


    reg [precision - 1 : 0] G1, G2;
    reg [(2* precision) - 1 : 0] d1, d2;

    reg [(4 * precision) -1 :0] conic_opacity0, conic_opacity1, conic_opacity2;

    reg [precision - 1 : 0] dL_dalpha;
    reg [precision - 1 : 0] alpha_calculated;
    
    reg skip_and_alpha_i_valid, gradient_depth_color_i_valid, gradient_gaussians_i_valid;

    reg [(3 * precision) - 1 : 0] gaussian_color0, gaussian_color1;
    reg [precision - 1 : 0] gaussian_depth0, gaussian_depth1;

    reg [(3 * precision) - 1 : 0] dL_dcolor2;
    reg [precision - 1 : 0] dL_ddepth2;    

    reg [10:0] H0, W0, H1, W1, H2, W2;

    reg [(3 * precision) - 1 : 0] dL_dpixel0, dL_dpixel1;
    reg [precision - 1 : 0] dL_dpixel_depth0, dL_dpixel_depth1;

    reg [(2* precision) - 1 : 0] mean2D0;


    wire skip_temp;
    wire dL_dalpha_valid;
    wire gradient_valid_temp;

    wire [precision - 1 : 0] T_out;
    wire [(3 * precision) - 1 : 0] color_out;
    wire [precision - 1 : 0] depth_out;
    wire [precision - 1 : 0] alpha_out;

    wire [(3 * precision) - 1 : 0] accum_rec_out;
    wire [precision - 1 : 0] accum_rec_depth_out;

    wire [precision - 1 : 0] dL_dalpha_out;
    
    wire [precision - 1 : 0] alpha_calculated_temp;

    wire [precision - 1 : 0] T_current_in;
    wire [precision - 1 : 0] dL_dopacity_temp, dL_ddepth_temp;
    wire [(3 * precision) - 1 : 0] dL_dcolor_temp;
    wire [(4 * precision) - 1 : 0] dL_dconic_temp;
    wire [(2* precision) - 1 : 0] dL_dmean2D_temp; 

    wire skip_and_alpha_done, gradient_depth_color_done;

    wire [precision - 1 : 0] G_out;
    wire [(2 * precision) - 1 : 0] d_out;
    wire gradient_depth_color_i_valid_temp;


    wire reason_from_alpha_range, reason_from_power_sign;
    

    //skip and alpha module
    // Phase 1 alpha and skip Logic
    skip_and_alpha #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision)) 
    skip_and_alpha_unit (.block_id(block_id), .mean2D(mean2D0), .i_valid(skip_and_alpha_i_valid),
    .conic_opacity(conic_opacity0), .pixel_id(pixel_id), .T_before(T_reg),

    .skip(skip_temp), .G(G_out), .d(d_out), .T(T_out), .alpha(alpha_calculated_temp) // , .skip_and_alpha_done(skip_and_alpha_done)
    );

    assign gradient_depth_color_i_valid_temp = skip_and_alpha_i_valid && !skip_temp;

    // Phase 2, Gradient Logic 1 (depth, color) & dL_dalpha
    // background 추가 처리 필요 (이거를 있다고 해야되나)
    gradient_depth_color #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision))
    gradient_depth_color_unit (.alpha_before(alpha_reg), .color_before(color_reg), .depth_before(depth_reg), .accum_rec_before(accum_rec_reg), .accum_rec_depth_before(accum_rec_depth_reg),
    .alpha_in(alpha_calculated), .T_in(T_reg), .gaussian_color(gaussian_color1), .gaussian_depth(gaussian_depth1), .i_valid(gradient_depth_color_i_valid), // .background_color(background_color),

    // gradient data input
    .dL_dpixel(dL_dpixel1), .dL_dpixel_depth(dL_dpixel_depth1), 
    
    //data for next stage
    .dL_dalpha(dL_dalpha_out), 

    // gradient of gaussians (will be used for update gaussians)
    .dL_dcolor(dL_dcolor_temp), .dL_ddepth(dL_ddepth_temp),

    // data for stage1
    .alpha_out(alpha_out), .color_out(color_out), .depth_out(depth_out), .accum_rec(accum_rec_out), .accum_rec_depth(accum_rec_depth_out) // , .dL_dalpha_valid(dL_dalpha_valid)
    );

    // Phase 3, Gradient Logic 2 dL_dmean2D, dL_dconic, dL_dopacity
    gradient_gaussians #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision))
    gradient_gaussians_unit (.W(W2), .H(H2), .G(G2), .d(d2), .dL_dalpha(dL_dalpha), .conic_opacity(conic_opacity2), .i_valid(gradient_gaussians_i_valid),
    
    // gradient output
    .dL_dmean2D(dL_dmean2D_temp), .dL_dconic(dL_dconic_temp), .dL_dopacity(dL_dopacity_temp),
    
    //valid signal
    .gradient_valid(gradient_valid_temp)
    );
    

    // clock
    always @ (posedge clk) begin
        if (!rst_n) begin
            {gradient_gaussians_i_valid, gradient_depth_color_i_valid, skip_and_alpha_i_valid} <= 3'b000;
            skip <= 1'b0;

            G1 <= 'h0;
            G2 <= 'h0;

            d1 <= 'h0;
            d2 <= 'h0;

            H0 <= 'h0;
            H1 <= 'h0;
            H2 <= 'h0;

            W0 <= 'h0;
            W1 <= 'h0;
            W2 <= 'h0;

            // T, color, depth, accum_rec, accum_rec_depth 는 다 하나로 합쳐도 될거 같음

            // Two input to One input
            T_reg <= 'h0;
            color_reg <= 'h0;
            alpha_reg <= 'h0;
            depth_reg <= 'h0;
            accum_rec_reg <= 'h0;
            accum_rec_depth_reg <= 'h0;

            dL_dalpha <= 'h0;
            dL_dcolor <= 'h0;
            dL_ddepth <= 'h0;
            dL_dmean2D <= 'h0;
            dL_dconic <= 'h0;
            dL_dopacity <= 'h0;

            gaussian_color0 <= 'h0;
            gaussian_color1 <= 'h0;

            gaussian_depth0 <= 'h0;
            gaussian_depth1 <= 'h0;

            conic_opacity0 <='h0;
            conic_opacity1 <='h0;
            conic_opacity2 <='h0;

            mean2D0 <='h0;

            dL_dcolor2 <= 'h0;
            dL_ddepth2 <= 'h0;

            dL_dpixel0 <= 'h0;
            dL_dpixel1 <= 'h0;
            dL_dpixel_depth0 <= 'h0;
            dL_dpixel_depth1 <= 'h0;

            gradient_valid_out <= 'b0;
        end
        
        else begin
            // if (!stall) begin

                skip_and_alpha_i_valid <= i_valid;
                gradient_depth_color_i_valid <= gradient_depth_color_i_valid_temp;
                gradient_gaussians_i_valid <= gradient_depth_color_i_valid;

                ////////////////////////////////////////////////////////////////////
                ///////////////////////// Stage 0 Data Input ///////////////////////
                ////////////////////////////////////////////////////////////////////

                gaussian_color0 <= gaussian_color;
                gaussian_depth0 <= gaussian_depth;

                conic_opacity0 <= conic_opacity;
                mean2D0 <= mean2D;

                dL_dpixel0 <= dL_dpixel;
                dL_dpixel_depth0 <= dL_dpixel_depth;

                H0 <= H;
                W0 <= W;

                ////////////////////////////////////////////////////////////////////
                /////////////////// Stage 1 Data (skip and alpha) //////////////////
                ////////////////////////////////////////////////////////////////////
                G1 <= G_out;

                H1 <= H0;
                W1 <= W0;

                d1 <= d_out;

                T_reg <= T_out;

                alpha_calculated <= alpha_calculated_temp;

                gaussian_color1 <= gaussian_color0;
                gaussian_depth1 <= gaussian_depth0;

                dL_dpixel1 <= dL_dpixel0;
                dL_dpixel_depth1 <= dL_dpixel_depth0;

                conic_opacity1 <= conic_opacity0;

                // Data input 을 기다릴 필요가 있을까? 에 대한 고찰 필요
                skip <= skip_temp && skip_and_alpha_i_valid;

                ////////////////////////////////////////////////////////////////////
                ////////////// Stage 2 Data (Gradient depth and color) /////////////
                ////////////////////////////////////////////////////////////////////
                G2 <= G1;
                d2 <= d1;
 
                alpha_reg <= alpha_out;
                color_reg <= color_out;
                depth_reg <= depth_out;
                accum_rec_reg <= accum_rec_out;
                accum_rec_depth_reg <= accum_rec_depth_out;


                dL_dcolor2 <= dL_dcolor_temp;
                dL_ddepth2 <= dL_ddepth_temp;

                H2 <= H1;
                W2 <= W1;

                dL_dalpha <= dL_dalpha_out;

                dL_dpixel1 <= dL_dpixel0;
                dL_dpixel_depth1 <= dL_dpixel_depth0;

                conic_opacity2 <= conic_opacity1;


                ////////////////////////////////////////////////////////////////////
                ///////////////// Stage 3 Data (Gradient gaussians) ////////////////
                ////////////////////////////////////////////////////////////////////

                dL_dmean2D <= dL_dmean2D_temp;
                dL_dconic <= dL_dconic_temp;
                dL_dopacity <= dL_dopacity_temp;

                dL_dcolor <= dL_dcolor2;
                dL_ddepth <= dL_ddepth2;

                gradient_valid_out <= gradient_valid_temp;
            // end
            //stall 에서 추가적인 뭔가를 할게 있으면
            // else begin
                
            // end    
        end
    end

endmodule