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
module Rasterizer_unit(

    //reset and clock
    input wire clk,
    input wire rst_n,
    
    // Backward input and output
    input wire [63:0] block_gaussian_range, // int32 x and y
    input wire [31:0] block_point_list,

    input wire [63:0] block_index , // block index x at [0] y at [1]

    input wire [31:0] width, //int 32 W
    input wire [31:0] height, //int 32 H
    
    input wire [95:0] background_color, //fp32 | R | G | B |

    input wire [63:0] means2D, //fp32 | X | Y | 
    input wire [127:0] conic_opacity, // fp32 | X | Y | Z | W |
    
    input wire [95:0] colors, //fp32 | R | G | B |
    input wire [31:0] depths, //fp32
    input wire [31:0] final_T, //fp32

    input wire [31:0] n_contrib, //int32

    input wire [95:0] dL_dpixels, //fp32 | R | G | B |
    input wire [31:0] dL_dpixel_depths, //fp32

    output reg [63:0] dL_dmean2D, //fp32 | X | Y |
    output reg [127:0] dL_dconic, //fp32 | X | Y | Z | W |
    output reg [31:0] dL_dopacity, //fp32 
    output reg [95:0] dL_dcolors, //fp32 | R | G | B |
    output reg [31:0] dL_ddepths, //fp32

    // Using ready-valid handshake
    // input ready-valid protocol
    input wire i_valid,
    output reg o_ready,
    
    // output ready-valid protocol
    input wire i_ready,
    output reg o_valid
    );

    //gaussian ID 기록해서 Gradient 계산 후 반환해야함

    reg skip = 1'b0;
    reg done = 1'b0;

    // | ---------------->>>> forward path  ---------------->>>> |
    // | <<<<---------------- backward path <<<<---------------- |
    //         | (next)
    //             | (current)


    reg [31:0] T_current, T_next;
    reg [31:0] alpha_current, alpha_next;
    reg [31:0] dL_dalpha_current, dL_dalpha_next;

    reg [95:0] last_color;

    reg [31:0] dL_dalpha= 32'h0;
    reg [31:0] current_contributor;

    // Phase 0, check for done
    always @ (*) begin
        // done contributor
    end

    // Phase 1, skip logic + alpha return
    //skip Logic 이후에 T가 업데이트되어 배출 가능 및 Phase 2의 Gradient Logic에 사용
    always @ (*) begin
        
    end

    always @ (posedge clk) begin
        if (!rst_n) begin
            
        end
        
        else begin
            skip <= ;
            alpha_current <= alpha_next;
            T_current <= T_next;
        end
    end
    
    // Phase 2, Gradient Logic 1 (depth, color) & dL_dalpha
    // background 추가 처리 필요 (이거를 있다고 해야되나)

    always @ (posedge clk) begin
        if (!rst_n) begin

        end

        else begin
            dL_dalpha_current <= dL_dalpha_next;
        end
    end
    

    // Phase 3, Gradient Logic 2 (mean2D, conic2D, opacity)

    always @ (posedge clk) begin
        if (!rst_n) begin

        end

        else begin

        end
    end
    


    // Phase 5, Gradient Summation Logic 
    
        
    
endmodule
