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
// Baseline
module Backward_Rasterizer_unit_single_input_original
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 7,
        parameter precision = 16,
        parameter GID_bit = 24
    )
(
    // input wire
    input wire clk,
    input wire rst_n,

    input wire [11:0] W, 
    input wire [11:0] H,

    // pixel dimension

    input wire i_valid  , // 1이면 valid, 0이면 invalid

    // 픽셀 처음 시작시에만 주면 되는 값들
    // input wire start  , // 시작시에만 Block id, pixel id , dL_dpixel, dL_dpixel_depth, 초기 T 값 이후 필요 없음. (Register 내부에서 사용)
    input wire start,
    input wire [(3 * precision) - 1:0] dL_dpixel, //fp32 | R | G | B |
    input wire [precision - 1:0] dL_dpixel_depth, //fp32
    input wire [precision - 1:0] T_first,    

    input wire [15:0] block_id, // block index x at [0] y at [1]  // 1920 이 16x16 으로 분해시 120이니까 최대 비트 7개면 가능 (32비트 쓰지말고)
    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id,

    input wire stall_backpressure,

    input wire last_input  ,

    // input wire [(3 * precision) - 1 : 0] background_color, //fp32 | R | G | B |

    input wire [(2 * precision) - 1:0] mean2D  , //fp32 | X | Y | 
    input wire [(4 * precision) - 1:0] conic_opacity  , // fp32 | X | Y | Z | W |

    input wire [GID_bit-1:0] gaussian_id  ,
    input wire [(3 * precision) - 1:0] gaussian_color  , //fp32 | R | G | B |
    input wire [precision - 1 : 0] gaussian_depth  , //fp32



    // output wire라고 간주 (어차피 gradient unit에서 reg 처리)
    output wire [(3 * precision) - 1:0] dL_dcolor_out, // fp32 | R | G | B |
    output wire [precision - 1:0] dL_ddepth_out, // fp32
    output wire [precision - 1:0] dL_dopacity_out, // fp32 
    output wire [(2 * precision) - 1:0] dL_dmean2D_out, // fp32 | X | Y |
    output wire [(4 * precision) - 1:0] dL_dconic_out, // fp32 | X | Y | Z | W |
    output wire [GID_bit-1:0] gaussian_id_out,


    // output wire [31:0] gaussian_id_out, // 나가는 gaussian ID도 명시해야함.

    output wire gradient_valid_out,

    output wire stall_to_controller,
    output wire last_input_done
    
    );
    // synopsys template

    // localparam stage1_latency = 7;
    // localparam stage2_latency = 9;
    // gaussian ID 기록해서 Gradient 계산 후 반환해야함

    // | ---------------->>>> forward path  ---------------->>>> |
    // | <<<<---------------- backward path <<<<---------------- |
    //         | (next)
    //             | (current)
    
    // Register decalaration

    // logic early_skip6   ;
    // logic early_skip7   ;

    logic [precision - 1:0] G_wire ;
    logic [(2 * precision) - 1:0] d_wire ;
    logic [precision - 1:0] alpha_wire ;
    logic skip_wire ;
    logic [(4 * precision) - 1:0] conic_opacity_wire ;
    logic skip_and_alpha_done_out ;

    logic [GID_bit-1:0] gaussian_id_wire ;
    logic [(3 * precision)-1:0] gaussian_color_wire ;
    logic [precision-1:0] gaussian_depth_wire ;

    logic src_ready_out;

    assign src_ready_out = !stall_backpressure;

    logic last_input_done_wire_from_skip_unit;
    
    
    logic input_gaussian_valid;
    assign input_gaussian_valid = !skip_wire && skip_and_alpha_done_out;

    assign stall_to_controller = stall_backpressure;

    //skip and alpha module
    // Phase 1 alpha and skip Logic

    Backward_skip_unit_single_input #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision), .GID_bit(GID_bit)) 
        skip_unit_stage1 (.clk(clk), .rst_n(rst_n), .block_id(block_id), .mean2D(mean2D), .conic_opacity(conic_opacity), .pixel_id(pixel_id), .i_valid(i_valid), // .early_skip(early_skip_from_stage1), // stage 5에서 나옴 (stage 2로 줄이는게 목적)
        .start(start), .gaussian_id_in(gaussian_id), .stall(stall_to_controller), .ready_from_arbiter(src_ready_out),
        .gaussian_color_in(gaussian_color), .gaussian_depth_in(gaussian_depth), .last_input(last_input),

        .skip_out(skip_wire), .G_out(G_wire), .d_out(d_wire), .alpha_out(alpha_wire), .conic_opacity_out(conic_opacity_wire),
        .gaussian_id_out(gaussian_id_wire), .gaussian_color_out(gaussian_color_wire), .gaussian_depth_out(gaussian_depth_wire),
        .skip_and_alpha_done_out(skip_and_alpha_done_out), .last_input_done(last_input_done_wire_from_skip_unit)
        );
    


    

    
     // Phase 3 Gradient Unit
        gradient_unit_original #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision), .GID_bit(GID_bit)) 
            gradient_unit_stage3 (.clk(clk), .rst_n(rst_n), .G(G_wire), .d(d_wire), .conic_opacity(conic_opacity_wire), .alpha_in(alpha_wire),
            .gaussian_color(gaussian_color_wire), .gaussian_depth(gaussian_depth_wire), .gaussian_id_in(gaussian_id_wire),

            .i_valid(input_gaussian_valid), 
            .start(start), .T_first(T_first), .W(W), .H(H),
            .dL_dpixel(dL_dpixel), .dL_dpixel_depth(dL_dpixel_depth),
            .stall(stall_backpressure),
            .last_input(last_input_done_wire_from_skip_unit),


            .dL_dcolor(dL_dcolor_out), .dL_ddepth(dL_ddepth_out), .dL_dmean2D(dL_dmean2D_out), .dL_dconic(dL_dconic_out), .dL_dopacity(dL_dopacity_out),
            .gaussian_id_out(gaussian_id_out),
            .gradient_valid_out(gradient_valid_out),
            .last_input_done(last_input_done)
        );

endmodule