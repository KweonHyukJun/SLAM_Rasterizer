module Backward_Block_controller_with_SRAM

#(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 4, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    parameter GID_bit = 11, // 2^11 - 1 = 2047
    parameter WINDOW_SIZE = 32,
    parameter Banks = 16,
    parameter GRADIENT_MERGE_TO_TOP_WIDTH = 11 * precision + GID_bit,
    parameter resoultion = 307200
)

// Testbench (Top controller && DDR RAM에서의 데이터)
(
    input wire clk,
    input wire rst_n,

    // From Top Controller
    input wire Block_data_done,
    input wire gradient_value_ready,

    input wire [11:0] W_in,
    input wire [11:0] H_in,
    input wire [15:0] block_id_in,

    input wire [GID_bit-1:0] last_gaussian_index_in, // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리
    
    
    // To Top controller
    output wire Block_data_ready,
    output wire gradient_value_valid,
    output wire gradient_value_done,


    // From External DDR Memory to SRAM
    input wire [(3 * precision) -1:0] gaussian_color_from_DDR,
    input wire [precision-1:0] gaussian_depth_from_DDR,
    input wire [(2 * precision)-1:0] mean2D_from_DDR,
    input wire [(4 * precision)-1:0] conic_opacity_from_DDR,
    input wire [GID_bit-1:0] gaussian_id_from_DDR,
    input wire [(2 * $clog2(BLOCK_SIZE))-1:0] pixel_id_from_DDR,

    input wire Gaussian_SRAM_WEB,


    input wire [(3 * precision)-1:0] dL_dpixel_from_DDR,
    input wire [precision-1:0] dL_dpixel_depth_from_DDR,
    input wire [precision-1:0] T_first_from_DDR,
    input wire [GID_bit-1:0] n_contrib_from_DDR,

    input wire Pixel_SRAM_WEB,

    



    // To External DDR Memory
    output wire push_to_Top_FIFO, // Gradient REB 0 이후? 혹은 동일 clock cycle에 발생
    output wire [GRADIENT_MERGE_TO_TOP_WIDTH-1:0] gradient_merge_to_Top_FIFO
);

    localparam GAUSSIAN_SRAM_DEPTH = 1 << GID_bit;
    localparam PIXEL_SRAM_DEPTH = 1 << ($clog2(num_pixels) + $clog2(BLOCK_SIZE));
    
    localparam GAUSSIAN_SRAM_WIDTH = 10 * precision;
    localparam PIXEL_SRAM_WIDTH = 5 * precision;
    localparam GRADIENT_MERGE_WIDTH = 11 * precision;



    // Wire declaration

        // Gaussian SRAM    
        wire [(10 * precision):0] gaussian_data_from_DDR;
        assign gaussian_data_from_DDR = {gaussian_color_from_DDR, gaussian_depth_from_DDR, mean2D_from_DDR, conic_opacity_from_DDR};

        wire [GID_bit-1:0] write_address_to_gaussian_SRAM;
        assign write_address_to_gaussian_SRAM = gaussian_id_from_DDR;


        wire [10 * precision -1:0] gaussian_data_from_SRAM;

        wire [3 * precision - 1:0] gaussian_color_from_SRAM;
        wire [precision - 1:0] gaussian_depth_from_SRAM;
        wire [(2 * precision)-1:0] mean2D_from_SRAM;
        wire [(4 * precision)-1:0] conic_opacity_from_SRAM;
        wire [GID_bit-1:0] gaussian_id_from_SRAM;

        assign {gaussian_color_from_SRAM, gaussian_depth_from_SRAM, mean2D_from_SRAM, conic_opacity_from_SRAM} = gaussian_data_from_SRAM;


        // Pixel SRAM
        wire [(5 * precision + GID_bit)-1:0] pixel_data_from_DDR;
        assign pixel_data_from_DDR = {dL_dpixel_from_DDR, dL_dpixel_depth_from_DDR, T_first_from_DDR, n_contrib_from_DDR};

        wire [(5 * precision + GID_bit)-1:0] pixel_data_from_SRAM;

        wire [precision-1:0] T_first_from_SRAM;
        wire [(3 * precision)-1:0] dL_dpixel_from_SRAM;
        wire [precision-1:0] dL_dpixel_depth_from_SRAM;
        wire [GID_bit-1:0] n_contrib_from_SRAM;

        assign {T_first_from_SRAM, dL_dpixel_from_SRAM, dL_dpixel_depth_from_SRAM, n_contrib_from_SRAM} = pixel_data_from_SRAM;


        // To Rasterizer
            // Gausisan Inputs
            wire [(3 * precision)-1:0] gaussian_color_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [precision-1:0] gaussian_depth_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [(2 * precision)-1:0] mean2D_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [(4 * precision)-1:0] conic_opacity_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire [GID_bit-1:0] gaussian_id_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
            wire i_valid [gaussian_inputs * num_pixels - 1:0];

            // Pixel Inputs
            wire start [num_pixels-1:0]; 
            wire [(3 * precision)-1:0] dL_dpixel_current [num_pixels-1:0];
            wire [precision-1:0] dL_dpixel_depth_current [num_pixels-1:0];
            wire [precision-1:0] T_first_current [num_pixels-1:0];
            wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_current [num_pixels-1:0];


        // To SRAM

            // Gaussian SRAM
            wire [GID_bit-1:0] Read_address_to_Gaussian_SRAM;
            wire REB_to_Gaussian_SRAM;

            // Pixel SRAM
            wire [2 * $clog2(num_pixels) - 1:0] Read_address_to_Pixel_SRAM;
            wire REB_to_Pixel_SRAM;

            // Gradient SRAM
            wire [GID_bit-1:0] Read_address_from_rasterizer_to_gradient_SRAM [Banks-1:0];
            wire REB_to_gradient_SRAM [Banks-1:0];
            wire WEB_to_gradient_SRAM [Banks-1:0];

        // To Block controller

        wire stall_to_controller_from_rasterizer [num_pixels-1:0];
        wire last_input_done_from_rasterizer [Banks-1:0];


        wire [GID_bit-1:0] next_n_contrib_from_SRAM;
        wire [precision-1:0] next_T_first_from_SRAM;
        wire [(3 * precision)-1:0] next_dL_dpixel_from_SRAM;
        wire [precision-1:0] next_dL_dpixel_depth_from_SRAM;





    Backward_Block_controller #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .exponent_bit(exponent_bit),
        .mantissa_bit(mantissa_bit),
        .precision(precision),
        .gaussian_inputs(gaussian_inputs),
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .WINDOW_SIZE(WINDOW_SIZE),
        .Banks(Banks)
    )
    Backward_Block_controller_inst (
        .clk(clk),
        .rst_n(rst_n),

        .Block_data_done(Block_data_done),
        .gradient_value_ready(gradient_value_ready),

        .W_in(W_in),
        .H_in(H_in),
        .block_id_in(block_id_in),

        .last_gaussian_index_in(last_gaussian_index_in),

        .Block_data_ready(Block_data_ready),
        .gradient_value_valid(gradient_value_valid),
        .gradient_value_done(gradient_value_done),

        .stall_to_controller_from_rasterizer(stall_to_controller_from_rasterizer),
        .last_input_done_from_rasterizer(last_input_done_from_rasterizer),

        .i_valid(i_valid),
        .gaussian_id_to_rasterizer(gaussian_id_to_rasterizer),
        .gaussian_color_to_rasterizer(gaussian_color_to_rasterizer),
        .gaussian_depth_to_rasterizer(gaussian_depth_to_rasterizer),
        .mean2D_to_rasterizer(mean2D_to_rasterizer),
        .conic_opacity_to_rasterizer(conic_opacity_to_rasterizer),


        .start(start),
        .T_first_current(T_first_current),
        .dL_dpixel_current(dL_dpixel_current),
        .dL_dpixel_depth_current(dL_dpixel_depth_current),
        .pixel_id_current(pixel_id_current),

        .gaussian_color_from_SRAM(gaussian_color_from_SRAM),
        .gaussian_depth_from_SRAM(gaussian_depth_from_SRAM),
        .mean2D_from_SRAM(mean2D_from_SRAM),
        .conic_opacity_from_SRAM(conic_opacity_from_SRAM),
        .gaussian_id_from_SRAM(gaussian_id_from_SRAM),

        .Read_address_to_Gaussian_SRAM(Read_address_to_Gaussian_SRAM),
        .REB_to_gaussian_SRAM(REB_to_gaussian_SRAM),

        .next_n_contrib_from_SRAM(next_n_contrib_from_SRAM),
        .next_T_first_from_SRAM(next_T_first_from_SRAM),
        .next_dL_dpixel_from_SRAM(next_dL_dpixel_from_SRAM),
        .next_dL_dpixel_depth_from_SRAM(next_dL_dpixel_depth_from_SRAM),

        .Read_address_to_Pixel_SRAM(Read_address_to_Pixel_SRAM),
        .REB_to_Pixel_SRAM(REB_to_Pixel_SRAM),

        .Read_address_from_rasterizer_to_gradient_SRAM(Read_address_from_rasterizer_to_gradient_SRAM),

        .REB_to_gradient_SRAM(REB_to_gradient_SRAM),
        .WEB_to_gradient_SRAM(WEB_to_gradient_SRAM)
    );

    dp_ram #( .N(GAUSSIAN_SRAM_WIDTH), .W(GAUSSIAN_SRAM_DEPTH))
    Gaussian_SRAM_inst(
        .clk(clk),
        // rst_n 없는 신호임
        .rst_n(rst_n),

        .AA(write_address_to_gaussian_SRAM), // write address
        .D(gaussian_data_from_DDR), // write data
        .WEB(Gaussian_SRAM_WEB), // write enable
        .AB(Read_address_to_Gaussian_SRAM), // read address
        .REB(REB_to_gaussian_SRAM), // read enable
        .Q(gaussian_data_from_SRAM) // read data
        

    );

    dp_ram #( .N(PIXEL_SRAM_WIDTH), .W(PIXEL_SRAM_DEPTH))
    Pixel_SRAM_inst(
        .clk(clk),
        // rst_n 없는 신호임
        .rst_n(rst_n),

        .AA(pixel_id_from_DDR), // write address
        .D(pixel_data_from_DDR), // write data
        .WEB(Pixel_SRAM_WEB), // write enable
        .AB(Read_address_to_Pixel_SRAM), // read address
        .REB(REB_to_Pixel_SRAM), // read enable
        .Q(pixel_data_from_SRAM) // read data
    );

    // // 이건 Raster module과 해서 추후 테스트 진행
    // genvar i;
    // generate
    //     for (i = 0; i < Banks; i++) begin : Gradient_SRAM_inst

    //         Combined_Backward_Rasterizer_and_merge #(
    //             .BLOCK_SIZE(BLOCK_SIZE),
    //             .exponent_bit(exponent_bit),
    //             .mantissa_bit(mantissa_bit),
    //             .precision(precision),
    //             .gaussian_inputs(gaussian_inputs),
    //             .num_pixels(num_pixels),
    //             .GID_bit(GID_bit),
    //             .WINDOW_SIZE(WINDOW_SIZE)
    //         )
    //         Combined_Backward_Rasterizer_and_merge_inst(

    //         );

    //         dp_ram #( .N(), .W(GAUSSIAN_SRAM_DEPTH) )
    //         Gradient_SRAM_inst(

    //         );
    //     end
    // endgenerate



    // // Gradient를 모으는 FIFO
    // // 이거 추후 테스트 진행
    // push_pop_fifo #(
    //     .DATA_WIDTH(GRADIENT_MERGE_WIDTH),
    //     .DEPTH(Banks)
    // )
    // TOP_Gradient_FIFO_inst(

    // );

endmodule