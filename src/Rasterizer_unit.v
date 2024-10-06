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
        parameter mantissa_bit = 23,
        parameter precision = 32
    )
(

    //reset and clock
    input wire clk,
    input wire rst_n,
    
    // // Backward input and output << move up to block controller
    // input wire [63:0] block_gaussian_range, // int32 x and y
    // input wire [31:0] block_point_list,

    input wire done, // pixel worker group controller에서 일하는 여부를 내려준다고 가정 (last contributor 이런것도 포함)

    input wire [31:0] W,
    input wire [31:0] H,

    input wire i_valid,

    input wire [ precision-1 :0] Test_T,
    input wire [ (3 * precision) - 1:0] Test_last_color,
    input wire [31:0] Test_last_depth,
    input wire [31:0] Test_last_alpha,
    input wire [95:0] Test_rec_accum,
    input wire [31:0] Test_rec_accum_depth,



    input wire [63:0] block_id , // block index x at [0] y at [1]
    
    // input wire [95:0] background_color, //fp32 | R | G | B |

    input wire [63:0] mean2D, //fp32 | X | Y | 
    input wire [127:0] conic_opacity, // fp32 | X | Y | Z | W |

    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id,

    // input wire [31:0] gaussian_id,
    input wire [95:0] gaussian_color, //fp32 | R | G | B |
    input wire [31:0] gaussian_depth, //fp32

    // input wire [31:0] final_T, //fp32 // 이거 픽셀 데이터인데 어떻게 하지? 스타트에 관한 신호를 넣어야 하나

    // input wire [31:0] n_contrib, //int32

    input wire [95:0] dL_dpixel, //fp32 | R | G | B |
    input wire [31:0] dL_dpixel_depth, //fp32

    output reg [63:0] dL_dmean2D, // fp32 | X | Y |
    output reg [127:0] dL_dconic, // fp32 | X | Y | Z | W |
    output reg [31:0] dL_dopacity, // fp32 
    output reg [95:0] dL_dcolor, // fp32 | R | G | B |
    output reg [31:0] dL_ddepth, // fp32
    
    output reg [31:0] dL_dalpha_out,

    output reg [2:0] state_out


    // 테스트용 초기 T 넣어야할듯...


    // output reg [31:0] gaussian_id_return

    // // Using ready-valid handshake
    // // input ready-valid protocol
    // input wire i_valid,
    // output reg o_ready,
    
    // // output ready-valid protocol
    // input wire i_ready,
    // output reg o_valid
    );

    // gaussian ID 기록해서 Gradient 계산 후 반환해야함



    wire skip;
    wire dL_dalpha_valid;
    wire gradient_valid;

    // | ---------------->>>> forward path  ---------------->>>> |
    // | <<<<---------------- backward path <<<<---------------- |
    //         | (next)
    //             | (current)

    //T_final을 어떻게 관리하는가

    reg [31:0] T_current, T_next;
    reg [95:0] color_current, color_next;
    reg [31:0] depth_current, depth_next;
    reg [31:0] alpha_current, alpha_next;

    reg [95:0] accum_rec_current, accum_rec_next;
    reg [31:0] accum_rec_depth_current, accum_rec_depth_next;

    wire [31:0] dL_dalpha;
    wire [31:0] alpha_calculated;
    reg [31:0] current_contributor;

    wire [31:0] G;
    wire [63:0] d;

    wire [31:0] dL_dopacity_temp, dL_ddepth_temp;
    wire [95:0] dL_dcolor_temp;
    wire [127:0] dL_dconic_temp;
    wire [63:0] dL_dmean2D_temp; 

    reg [1:0] state_next;

    wire skip_and_alpha_i_valid, gradient_depth_color_i_valid, gradient_gaussians_i_valid;
    wire skip_and_alpha_done, gradient_depth_color_done;


    // Phase 1, skip logic + alpha return
    //skip Logic 이후에 T가 업데이트되어 배출 가능 및 Phase 2의 Gradient Logic에 사용


    //skip and alpha module
    assign skip_and_alpha_i_valid = i_valid;    
    skip_and_alpha #( .BLOCK_SIZE(16), .exponent_bit(8), .mantissa_bit(23), .precision(32)) 
    skip_and_alpha_unit (.clk(clk), .rst_n(rst_n), .block_id(block_id), .mean2D(mean2D), .i_valid(skip_and_alpha_i_valid),
    .conic_opacity(conic_opacity), .pixel_id(pixel_id), .T_before(T_current),
    .skip(skip), .G(G), .d(d), .T(T_next), .alpha(alpha_calculated), .skip_and_alpha_done(skip_and_alpha_done));


    // Phase 2, Gradient Logic 1 (depth, color) & dL_dalpha
    // background 추가 처리 필요 (이거를 있다고 해야되나)
    assign gradient_depth_color_i_valid = !skip && skip_and_alpha_done ; // 이거만 하면 계속 1이 떠있는데


    gradient_depth_color #( .BLOCK_SIZE(16), .exponent_bit(8), .mantissa_bit(23), .precision(32)) 
    gradient_depth_color_unit (.clk(clk), .rst_n(rst_n), .alpha_before(alpha_current), .color_before(color_current), .depth_before(depth_current), .accum_rec_before(accum_rec_current), .accum_rec_depth_before(accum_rec_depth_current),
    .alpha_in(alpha_calculated), .T_in(T_current), .gaussian_color(gaussian_color), .gaussian_depth(gaussian_depth), .i_valid(gradient_depth_color_i_valid), // .background_color(background_color),

    // gradient data input
    .dL_dpixel(dL_dpixel), .dL_dpixel_depth(dL_dpixel_depth), .dL_dalpha(dL_dalpha), 

    // gradient of gaussians (will be used for update gaussians)
    .dL_dcolor(dL_dcolor), .dL_ddepth(dL_ddepth),

    // data for next stage
    .alpha_out(alpha_next), .color_out(color_next), .depth_out(depth_next), .accum_rec(accum_rec_next), .accum_rec_depth(accum_rec_depth_next), .dL_dalpha_valid(dL_dalpha_valid), .gradient_depth_color_done(gradient_depth_color_done)
    );

    // Phase 3, Gradient Logic 2 (mean2D, conic2D, opacity)
    assign gradient_gaussians_i_valid = dL_dalpha_valid && gradient_depth_color_done;
    gradient_gaussians #( .BLOCK_SIZE(16), .exponent_bit(8), .mantissa_bit(23), .precision(32))
    gradient_gaussians_unit (.clk(clk), .rst_n(rst_n), .W(W), .H(H), .G(G), .d(d), .dL_dalpha(dL_dalpha), .conic_opacity(conic_opacity), .i_valid(gradient_gaussians_i_valid),
    
    // gradient output
    .dL_dmean2D(dL_dmean2D), .dL_dconic(dL_dconic), .dL_dopacity(dL_dopacity),
    
    //valid signal
    .gradient_valid(gradient_valid)
    );
    
    // Phase 4 (Can Be or cannot be)
    // Gradient adding 

    // T (T_next), last_alpha (alpha_next) ... update
    always @ (*) begin
        T_current = T_next;
        alpha_current = alpha_next;
        color_current = color_next;
        depth_current = depth_next;
        accum_rec_current = accum_rec_next;
        accum_rec_depth_current = accum_rec_depth_next;
    end    

    always @ (*) begin
        dL_dalpha_out = dL_dalpha;
        state_out = {gradient_gaussians_i_valid, gradient_depth_color_i_valid, skip_and_alpha_i_valid};
    end


    //Test value 

    always @ (*) begin
        T_current = Test_T; 
        color_current = Test_last_color;
        alpha_current = Test_last_alpha;
        depth_current = Test_last_depth;
        accum_rec_current = Test_rec_accum;
        accum_rec_depth_current = Test_rec_accum_depth;
    end    



    // FSM for what to work

    // always @ (posedge clk) begin
    //     if (!rst_n) begin
    //         state_out <= IDLE;
    //     end
    //     else begin
    //         state_out <= state_next;
    //     end    
    // end


    // always  @ (*) begin
    //     state_next = state_out;
        
    //     case (state_out)
    //         IDLE: begin // 2'b00
    //             if (!done && i_valid) 
    //                 state_next = SKIP_CALC;
    //         end

    //         SKIP_CALC : begin // 2'b01
    //             if (!skip) 
    //                 state_next = dL_dalpha_CALC;
    //             else if (skip && i_valid)
    //                 state_next = SKIP_CALC;
    //         end

    //         dL_dalpha_CALC : begin // 2b'10
    //             if (dL_dalpha_valid)
    //                 state_next = dL_dGaussian_CALC;
    //         end

    //         dL_dGaussian_CALC : begin // 2b'11
    //             if (gradient_valid && !i_valid)
    //                 state_next = IDLE;
    //             else if (gradient_valid && i_valid)
    //                 state_next = SKIP_CALC;
    //         end

    //         default: state_next = IDLE;  // Default state is IDLE
    //     endcase 
    // end

endmodule
