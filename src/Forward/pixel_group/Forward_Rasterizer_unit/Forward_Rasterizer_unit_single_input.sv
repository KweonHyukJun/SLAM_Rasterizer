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
module Forward_Rasterizer_unit_single_input
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

    // input wire [11:0] W, 
    // input wire [11:0] H,

    // pixel dimension

    input wire i_valid , // 1이면 valid, 0이면 invalid

    // 픽셀 처음 시작시에만 주면 되는 값들
    // input wire start , // 시작시에만 Block id, pixel id , dL_dpixel, dL_dpixel_depth, 초기 T 값 이후 필요 없음. (Register 내부에서 사용)
    input wire start,
    // input wire [(3 * precision) - 1:0] dL_dpixel, //fp32 | R | G | B |
    // input wire [precision - 1:0] dL_dpixel_depth, //fp32
    // input wire [precision - 1:0] T_first,    

    input wire [15:0] block_id, // block index x at [0] y at [1]  // 1920 이 16x16 으로 분해시 120이니까 최대 비트 7개면 가능 (32비트 쓰지말고)
    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id,

    input wire stall_backpressure,

    input wire last_input ,


    // input wire [(3 * precision) - 1 : 0] background_color, //fp32 | R | G | B |

    input wire [(2 * precision) - 1:0] mean2D , //fp32 | X | Y | 
    input wire [(4 * precision) - 1:0] conic_opacity , // fp32 | X | Y | Z | W |

    input wire [GID_bit-1:0] gaussian_id ,
    input wire [(3 * precision) - 1:0] gaussian_color , //fp32 | R | G | B |
    input wire [precision - 1 : 0] gaussian_depth , //fp32


    output wire [GID_bit-1:0] gaussian_id_out,

    // output wire [31:0] gaussian_id_out, // 나가는 gaussian ID도 명시해야함.

    output wire pixel_valid_out,

    output wire stall_to_controller,

    output wire [(3 * precision)-1:0] pixel_color_out,
    output wire [precision-1:0] pixel_depth_out,
    output wire [11:0] n_contrib_out,
    output wire [precision-1:0] pixel_opacity_out,
    output wire [precision-1:0] T_first_out
    );
    //synopsys template

    // | ---------------->>>> forward path  ---------------->>>> |
    // | <<<<---------------- backward path <<<<---------------- |
    //         | (next)
    //             | (current)
    
    // Register decalaration
    logic [precision - 1:0] alpha_wire ;
    logic skip_wire ;
    logic [(4 * precision) - 1:0] conic_opacity_wire ;
    logic skip_and_alpha_done_out ;

    // logic stall_from_arbiter;
    logic valid_to_splatting_unit;
    logic [GID_bit-1:0] gaussian_id_wire ;
    logic [(3 * precision)-1:0] gaussian_color_wire ;
    logic [precision-1:0] gaussian_depth_wire ;

    localparam ARBITER_DATA_SIZE = 5 * precision + GID_bit + 12; //  alpha(1), gaussian_color(3), depth(1) // id(32), n_contrib(12)
    
    logic [ARBITER_DATA_SIZE-1:0] arbiter_data_out;
    
    logic src_valid_temp ;
    logic [ARBITER_DATA_SIZE-1:0] src_data_arbiter ;
    logic src_ready_out ;

    logic [(3 * precision)-1:0] gaussian_color_to_splatting_unit;
    logic [precision-1:0]   gaussian_depth_to_splatting_unit;
    logic [precision-1:0]   alpha_to_splatting_unit;
    logic [GID_bit-1:0]     gaussian_id_to_splatting_unit;
    
    logic [11:0] n_contrib_wire ;

    logic last_input_done_wire_from_skip_unit ;
    logic last_input_done_wire_from_arbiter;

    logic [11:0] n_contrib_to_splatting_unit;

    // assign stage1_stall = stall_backpressure || stall_from_arbiter;
    // assign stall_to_controller = stage1_stall;
    assign stall_to_controller = stall_backpressure ;
    // Phase 1 alpha and skip Logic

    Forward_skip_unit_single_input #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .GID_bit(GID_bit)
    ) 
    skip_unit_stage1 (
        // Input
        .clk(clk), 
        .rst_n(rst_n), 
        .block_id(block_id), 
        .mean2D(mean2D), 
        .conic_opacity(conic_opacity), 
        .pixel_id(pixel_id), 
        .i_valid(i_valid), 
        .start(start), 
        .gaussian_id_in(gaussian_id), 
        .stall(stall_to_controller), 
        .ready_from_arbiter(!stall_to_controller),
        .gaussian_color_in(gaussian_color), 
        .gaussian_depth_in(gaussian_depth), 
        .last_input(last_input),
        
        // Output
        .skip_out(skip_wire), 
        // .G_out(G_wire), 
        // .d_out(d_wire), 
        .alpha_out(alpha_wire), 
        // .conic_opacity_out(conic_opacity_wire),
        .gaussian_id_out(gaussian_id_wire), 
        .gaussian_color_out(gaussian_color_wire), 
        .gaussian_depth_out(gaussian_depth_wire),
        .skip_and_alpha_done_out(skip_and_alpha_done_out), 

        .n_contrib_out(n_contrib_wire),

        .last_input_done(last_input_done_wire_from_skip_unit)
        );
    

    
    
    // // Phase 2, Skip Arbitration (Combinational Logic)
    // fixed_arbiter #(
    //     .N_MASTER(gaussian_inputs), 
    //     .DATA_SIZE(ARBITER_DATA_SIZE)
    // )
    // fixed_arbiter_stage2 (
    //     .clk(clk), .rst_n(rst_n),  
    //     .src_valid_i(src_valid_temp), 
    //     .src_data_i(src_data_arbiter),
    //     .last_input_done_i(last_input_done_wire_from_skip_unit),


    //     .src_ready_o(src_ready_out),
    //     .last_input_done_o(last_input_done_wire_from_arbiter),

    //     .stall_from_arbiter(stall_from_arbiter),
    //     .stall_backpressure(stall_backpressure),

    //     .dst_valid_o(valid_to_splatting_unit),  // .dst_ready_i(!stall_backpressure), 
    //     .dst_data_o(arbiter_data_out)
    //  );

    
    // generate
    //     for (genvar i = 0; i < gaussian_inputs; i++) begin : gen_arbiter_inputs
    //         assign src_valid_temp[i] = skip_and_alpha_done_out[i] & !skip_wire[i]; // Use ~ instead of ! for bitwise NOT
    //         assign src_data_arbiter[i] = {
    //                                     // G_wire[i],                  // 1*precision
    //                                     // d_wire[i],                   // 2*precision  
    //                                     // conic_opacity_wire[i],        // 4*precision
    //                                     alpha_wire[i],                // 1*precision
    //                                     gaussian_color_wire[i],       // 3*precision
    //                                     gaussian_depth_wire[i],       // 1*precision
    //                                     gaussian_id_wire[i],
    //                                     n_contrib_wire[i]
    //                                     };         // GID_bit
    //     end
    // endgenerate
    

    assign src_valid_temp = skip_and_alpha_done_out & !skip_wire; // Use ~ instead of ! for bitwise NOT
    assign src_data_arbiter = {
                                        // G_wire[i],                  // 1*precision
                                        // d_wire[i],                   // 2*precision  
                                        // conic_opacity_wire[i],        // 4*precision
                                        alpha_wire,                // 1*precision
                                        gaussian_color_wire,       // 3*precision
                                        gaussian_depth_wire,       // 1*precision
                                        gaussian_id_wire,
                                        n_contrib_wire
                                        };     

    // assign {alpha_to_splatting_unit, gaussian_color_to_splatting_unit, gaussian_depth_to_splatting_unit, gaussian_id_to_splatting_unit, n_contrib_to_splatting_unit} = arbiter_data_out;
    
     // Phase 3 Gradient Unit
    splatting_unit #( 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .GID_bit(GID_bit) 
    )    
    splatting_unit_stage3 (
        .clk(clk), .rst_n(rst_n), 

        .alpha_in(alpha_wire),
        .n_contrib_in(n_contrib_wire),
        .stall(stall_backpressure),
        .last_input(last_input_done_wire_from_skip_unit),
        
        .start(start), 

        .gaussian_id_in(gaussian_id_wire),
        .gaussian_color(gaussian_color_wire), 
        .gaussian_depth(gaussian_depth_wire), 
        
        .i_valid(src_valid_temp), 

        // Output
        .gaussian_id_out(gaussian_id_out),
        .pixel_color(pixel_color_out),
        .pixel_depth(pixel_depth_out),

        .n_contrib_out(n_contrib_out),
        .pixel_opacity(pixel_opacity_out),
        .T_first(T_first_out),
        .pixel_valid_out(pixel_valid_out)
        );


    // clock
    // always_ff @ (posedge clk) begin
    //     if (!rst_n) begin
    //         for (int i = 0; i < gaussian_inputs; i++) begin
    //             early_skip6[i] <= 'b0;
    //             early_skip7[i] <= 'b0;
    //         end

    //         // gaussian_id_out <= '0;
    //         // G_out <= '0;
    //         // d_out <= '0;
    //         // alpha_out <= '0;
    //         // conic_opacity_out <= '0;
    //         // valid_to_splatting_unit_out <= '0;
    //         // stall_to_controller <= 'b0;

    //     end
    //     else begin
    //         if (!stall_backpressure) begin
    //             early_skip6 <= early_skip_from_stage1;
    //             early_skip7 <= early_skip6;
    //         end

    //         // else begin
    //             // stall_to_controller <= stage1_stall || stall_backpressure;
    //         // end
    //     end
    // end

endmodule