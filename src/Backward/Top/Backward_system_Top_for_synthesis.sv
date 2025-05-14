module Backward_system_Top_for_synthesis #(
    parameter precision = 16,
    parameter mantissa_bit = 7,
    parameter exponent_bit = 8,
    parameter num_pixels = 16,
    parameter GID_bit = 12,
    parameter Banks = 16,
    parameter gaussian_inputs = 8,
    parameter GRADIENT_MERGE_TO_TOP_WIDTH = 11 * precision,
    parameter Gaussian_Range_Bit = 24,
    parameter GAUSSIAN_SRAM_DEPTH = 1 << GID_bit,
    parameter WINDOW_SIZE = 32,
    parameter BLOCK_SIZE = 16
)
(
    // Basic input
    input wire clk,
    input wire rst_n,


    // Top controller signal
    input wire backward_start,
    output wire backward_ready,
    output wire backward_done,

    
    input wire [11:0] W_in,
    input wire [11:0] H_in,

    input wire [31:0] base_address,

    // AXI channel


        // Range
            input wire range_rsta_busy,
            input wire range_rstb_busy,

            // aw channel
            output wire [11:0] range_s_axi_awid,
            output wire [13:0] range_s_axi_awaddr,
            output wire [7:0] range_s_axi_awlen,
            output wire [2:0] range_s_axi_awsize,
            output wire [1:0] range_s_axi_awburst,
            output wire range_s_axi_awvalid,
            input wire range_s_axi_awready,

            // w channel
            output wire [47:0] range_s_axi_wdata,
            output wire [31:0] range_s_axi_wstrb,
            output wire range_s_axi_wlast,
            output wire range_s_axi_wvalid,
            input wire range_s_axi_wready,

            // b channel
            input wire [11:0] range_s_axi_bid,
            input wire [1:0] range_s_axi_bresp,
            input wire range_s_axi_bvalid,
            output wire range_s_axi_bready,

            // ar channel
            output wire [11:0] range_s_axi_arid,
            output wire [13:0] range_s_axi_araddr,
            output wire [7:0] range_s_axi_arlen,
            output wire [2:0] range_s_axi_arsize,
            output wire [1:0] range_s_axi_arburst,
            output wire range_s_axi_arvalid,
            input wire range_s_axi_arready,

            // r channel
            input wire [11:0] range_s_axi_rid,
            input wire [47:0] range_s_axi_rdata,
            input wire [1:0] range_s_axi_rresp,
            input wire range_s_axi_rlast,
            input wire range_s_axi_rvalid,
            output wire range_s_axi_rready,

        // Point list
            input wire point_list_rsta_busy,
            input wire point_list_rstb_busy,

            // aw channel
            output wire [11:0] point_list_s_axi_awid,
            output wire [Gaussian_Range_Bit-1:0] point_list_s_axi_awaddr,
            output wire [7:0] point_list_s_axi_awlen,
            output wire [2:0] point_list_s_axi_awsize,
            output wire [1:0] point_list_s_axi_awburst,
            output wire point_list_s_axi_awvalid,
            input wire point_list_s_axi_awready,

            // w channel
            output wire [Gaussian_Range_Bit-1:0] point_list_s_axi_wdata,
            output wire [31:0] point_list_s_axi_wstrb,
            output wire point_list_s_axi_wlast,
            output wire point_list_s_axi_wvalid,
            input wire point_list_s_axi_wready,

            // b channel
            input wire [11:0] point_list_s_axi_bid,
            input wire [1:0] point_list_s_axi_bresp,
            input wire point_list_s_axi_bvalid,
            output wire point_list_s_axi_bready,

            // ar channel
            output wire [11:0] point_list_s_axi_arid,
            output wire [Gaussian_Range_Bit-1:0] point_list_s_axi_araddr,
            output wire [7:0] point_list_s_axi_arlen,
            output wire [2:0] point_list_s_axi_arsize,
            output wire [1:0] point_list_s_axi_arburst,
            output wire point_list_s_axi_arvalid,
            input wire point_list_s_axi_arready,

            // r channel
            input wire [11:0] point_list_s_axi_rid,
            input wire [Gaussian_Range_Bit-1:0] point_list_s_axi_rdata,
            input wire [1:0] point_list_s_axi_rresp,
            input wire point_list_s_axi_rlast,
            input wire point_list_s_axi_rvalid,
            output wire point_list_s_axi_rready,

        // Gaussian
            input wire gaussian_rsta_busy,
            input wire gaussian_rstb_busy,

            // aw channel
            output wire [11:0] gaussian_s_axi_awid,
            output wire [23:0] gaussian_s_axi_awaddr,
            output wire [7:0] gaussian_s_axi_awlen,
            output wire [2:0] gaussian_s_axi_awsize,
            output wire [1:0] gaussian_s_axi_awburst,
            output wire gaussian_s_axi_awvalid,
            input wire gaussian_s_axi_awready,

            // w channel
            output wire [10 * precision - 1:0] gaussian_s_axi_wdata,
            output wire [31:0] gaussian_s_axi_wstrb,
            output wire gaussian_s_axi_wlast,
            output wire gaussian_s_axi_wvalid,
            input wire gaussian_s_axi_wready,

            // b channel
            input wire [11:0] gaussian_s_axi_bid,
            input wire [1:0] gaussian_s_axi_bresp,
            input wire gaussian_s_axi_bvalid,
            output wire gaussian_s_axi_bready,

            // ar channel
            output wire [11:0] gaussian_s_axi_arid,
            output wire [23:0] gaussian_s_axi_araddr,
            output wire [7:0] gaussian_s_axi_arlen,
            output wire [2:0] gaussian_s_axi_arsize,
            output wire [1:0] gaussian_s_axi_arburst,
            output wire gaussian_s_axi_arvalid,
            input wire gaussian_s_axi_arready,

            // r channel
            input wire [11:0] gaussian_s_axi_rid,
            // input wire [159:0] gaussian_s_axi_rdata,
            input wire [1:0] gaussian_s_axi_rresp,
            input wire gaussian_s_axi_rlast,
            input wire gaussian_s_axi_rvalid,
            output wire gaussian_s_axi_rready,

        // Pixel
            input wire pixel_rsta_busy,
            input wire pixel_rstb_busy,

            // aw channel
            output wire [11:0] pixel_s_axi_awid,
            output wire [23:0] pixel_s_axi_awaddr,
            output wire [7:0] pixel_s_axi_awlen,
            output wire [2:0] pixel_s_axi_awsize,
            output wire [1:0] pixel_s_axi_awburst,
            output wire pixel_s_axi_awvalid,
            input wire pixel_s_axi_awready,

            // w channel
            output wire [(5*precision) + GID_bit -1:0] pixel_s_axi_wdata,
            output wire [31:0] pixel_s_axi_wstrb,
            output wire pixel_s_axi_wlast,
            output wire pixel_s_axi_wvalid,
            input wire pixel_s_axi_wready,

            // b channel
            input wire [11:0] pixel_s_axi_bid,
            input wire [1:0] pixel_s_axi_bresp,
            input wire pixel_s_axi_bvalid,
            output wire pixel_s_axi_bready,

            // ar channel
            output wire [11:0] pixel_s_axi_arid,
            output wire [23:0] pixel_s_axi_araddr,
            output wire [7:0] pixel_s_axi_arlen,
            output wire [2:0] pixel_s_axi_arsize,
            output wire [1:0] pixel_s_axi_arburst,
            output wire pixel_s_axi_arvalid,
            input wire pixel_s_axi_arready,

            // r channel
            input wire [11:0] pixel_s_axi_rid,
            input wire [(5*precision) + GID_bit -1:0] pixel_s_axi_rdata,
            input wire [1:0] pixel_s_axi_rresp,
            input wire pixel_s_axi_rlast,
            input wire pixel_s_axi_rvalid,
            output wire pixel_s_axi_rready,

        // Gradient
            input wire gradient_rsta_busy,
            input wire gradient_rstb_busy,

            // aw channel
            output wire [11:0] gradient_s_axi_awid,
            output wire [23:0] gradient_s_axi_awaddr,
            output wire [7:0] gradient_s_axi_awlen,
            output wire [2:0] gradient_s_axi_awsize,
            output wire [1:0] gradient_s_axi_awburst,
            output wire gradient_s_axi_awvalid,
            input wire gradient_s_axi_awready,

            // w channel
            output wire [11 * precision -1:0] gradient_s_axi_wdata,
            output wire [(11*precision / 8) - 1 : 0] gradient_s_axi_wstrb,
            output wire gradient_s_axi_wlast,
            output wire gradient_s_axi_wvalid,
            input wire gradient_s_axi_wready,

            // b channel
            input wire [11:0] gradient_s_axi_bid,
            input wire [1:0] gradient_s_axi_bresp,
            input wire gradient_s_axi_bvalid,
            output wire gradient_s_axi_bready,

            // ar channel
            output wire [11:0] gradient_s_axi_arid,
            output wire [23:0] gradient_s_axi_araddr,
            output wire [7:0] gradient_s_axi_arlen,
            output wire [2:0] gradient_s_axi_arsize,
            output wire [1:0] gradient_s_axi_arburst,
            output wire gradient_s_axi_arvalid,
            input wire gradient_s_axi_arready,

            // r channel
            input wire [11:0] gradient_s_axi_rid,
            input wire [11 * precision -1:0] gradient_s_axi_rdata,
            input wire [1:0] gradient_s_axi_rresp,
            input wire gradient_s_axi_rlast,
            input wire gradient_s_axi_rvalid,
            output wire gradient_s_axi_rready,
    
    // Cache SRAM


        // Point list

            // Top
            output wire [GID_bit-1:0] gaussian_ID_address_to_point_list_SRAM,
            output wire [Gaussian_Range_Bit-1:0] gaussian_ID_to_point_list_SRAM,
            output wire Point_list_WEB,

            output wire [GID_bit-1:0] gaussian_ID_read_address_point_list_SRAM,
            input wire [Gaussian_Range_Bit-1:0] gaussian_ID_from_point_list_SRAM,
            output wire Point_list_REB,




        // Gaussian

            // Top
            output wire [GID_bit-1:0] write_address_to_gaussian_SRAM [gaussian_inputs-1:0],
            output wire Gaussian_SRAM_WEB [gaussian_inputs-1:0],

            // Data to SRAM is from AXI4 rdata


            // Block
            output wire [GID_bit-1:0] gaussian_id_to_SRAM [gaussian_inputs-1:0],
            output wire REB_to_gaussian_SRAM [gaussian_inputs-1:0],

            // pixel_data를 나눠야함
            input wire [10 * precision -1:0] gaussian_data_from_SRAM [gaussian_inputs-1:0],


        // Pixel

            // Top
            output wire [$clog2(num_pixels)-1:0] write_address_to_pixel_SRAM [num_pixels-1:0],
            output wire Pixel_SRAM_WEB [num_pixels-1:0],

            // Data to SRAM is from AXI4 rdata


            // Block
            output wire [$clog2(num_pixels) - 1:0] Read_address_to_Pixel_SRAM [num_pixels-1:0],
            output wire REB_to_Pixel_SRAM [num_pixels-1:0],

            // pixel_data를 나눠야함
            input wire [5 * precision + GID_bit -1:0] pixel_data_from_SRAM [num_pixels-1:0],

           



        // Gradient

            // Top
            input wire push_to_Top_FIFO,
            input wire [11 * precision -1:0] gradient_merge_to_Top_FIFO,

            output wire Gradient_SRAM_REB_from_Top_control [Banks-1:0],
            output wire [GID_bit-1:0] gradient_id_to_SRAM_from_Top_control [Banks-1:0],

            output wire Gradient_SRAM_WEB_from_Top_control [Banks-1:0],
            

            // Block
            output wire WEB_to_gradient_SRAM [Banks-1:0],
            output wire REB_to_gradient_SRAM [Banks-1:0],

            output wire gradient_ID_used [Banks-1:0],

            output wire [GAUSSIAN_SRAM_DEPTH-1:0] gradient_first_used_LUT,


            // Gradient Merge FIFO
            input wire [11 * precision -1:0] SRAM_data_in_to_Adder [Banks-1:0],

            output wire [11 * precision -1:0] FIFO_to_SRAM_data [Banks-1:0],



            output wire [GID_bit-1:0] Read_address_before_add [Banks-1:0],

            output wire [GID_bit-1:0] Write_address_after_add [Banks-1:0]

);


// internal wire declaration

// Top-Block control
wire Block_data_ready;
wire gradient_value_valid;

wire Block_data_done;
wire gradient_value_ready;

wire [11:0] W;
wire [11:0] H;

wire [11:0] W_to_rasterizer;
wire [11:0] H_to_rasterizer;

wire [15:0] block_id_from_top_control_to_block_control;
wire [15:0] block_id;

wire [GID_bit-1:0] block_gaussian_range_out;



// Block - Rasterizer
wire stall_to_controller_from_rasterizer [num_pixels-1:0];
wire stall_to_rasterizer_to_controller;
wire stall_backpressure_from_controller;

wire last_input_done_from_rasterizer [num_pixels-1:0];
wire last_input_done_from_gradient_merge [Banks-1:0];

wire FIFO_pop_valid_in [Banks-1:0];
wire FIFO_pop_ready_out [Banks-1:0];

wire last_input_done_and_data_zero [Banks-1:0];

// Input from SRAM
    wire [3 * precision -1:0] gaussian_color_from_SRAM [gaussian_inputs-1:0];
    wire [precision-1:0] gaussian_depth_from_SRAM [gaussian_inputs-1:0];
    wire [(2 * precision)-1:0] mean2D_from_SRAM [gaussian_inputs-1:0];
    wire [(4 * precision)-1:0] conic_opacity_from_SRAM [gaussian_inputs-1:0];


    wire [3 * precision -1:0] next_dL_dpixel_from_SRAM [num_pixels-1:0];
    wire [precision-1:0] next_dL_dpixel_depth_from_SRAM [num_pixels-1:0];
    wire [precision-1:0] next_T_first_from_SRAM [num_pixels-1:0];
    wire [GID_bit-1:0] next_n_contrib_from_SRAM [num_pixels-1:0];


// To Rasterizer
    // Gausisan Inputs
    wire [(3 * precision)-1:0] gaussian_color_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
    wire [precision-1:0] gaussian_depth_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
    wire [(2 * precision)-1:0] mean2D_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
    wire [(4 * precision)-1:0] conic_opacity_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
    wire [GID_bit-1:0] gaussian_id_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
    wire i_valid [gaussian_inputs * num_pixels - 1:0];

    wire last_input_done_to_rasterizer [gaussian_inputs * num_pixels - 1:0];




    // Pixel Inputs
    wire start [num_pixels-1:0]; 
    wire [(3 * precision)-1:0] dL_dpixel_current [num_pixels-1:0];
    wire [precision-1:0] dL_dpixel_depth_current [num_pixels-1:0];
    wire [precision-1:0] T_first_current [num_pixels-1:0];
    wire [(2 * $clog2(num_pixels) - 1): 0] pixel_id_current [num_pixels-1:0];




genvar gau, pix;

generate 
    for (gau = 0 ; gau < gaussian_inputs ; gau++) begin : gaussian_input_loop

        assign gaussian_color_from_SRAM[gau] = gaussian_data_from_SRAM[gau][10 * precision - 1:7 * precision];
        assign gaussian_depth_from_SRAM[gau] = gaussian_data_from_SRAM[gau][7 * precision - 1:6 * precision];
        assign mean2D_from_SRAM[gau] = gaussian_data_from_SRAM[gau][6 * precision - 1:4 * precision];
        assign conic_opacity_from_SRAM[gau] = gaussian_data_from_SRAM[gau][4* precision - 1:0];

    end

    for (pix = 0 ; pix < num_pixels ; pix++) begin : pixel_input_loop

        assign next_dL_dpixel_from_SRAM[pix] = pixel_data_from_SRAM[pix][(5 * precision) + GID_bit - 1: (2 * precision) + GID_bit];
        assign next_dL_dpixel_depth_from_SRAM[pix] = pixel_data_from_SRAM[pix][(2 * precision) + GID_bit - 1: precision + GID_bit];
        assign next_T_first_from_SRAM[pix] = pixel_data_from_SRAM[pix][precision + GID_bit - 1:GID_bit];
        assign next_n_contrib_from_SRAM[pix] = pixel_data_from_SRAM[pix][GID_bit-1:0];
    end

endgenerate



// Dummy signals

wire s_aresetn;



// division of input signal

Backward_top_controller_AXI4_fetching #(
    .precision(precision),
    .mantissa_bit(mantissa_bit),
    .exponent_bit(exponent_bit),
    .num_pixels(num_pixels),
    .GID_bit(GID_bit),
    .Banks(Banks),
    .gaussian_inputs(gaussian_inputs),
    .GRADIENT_MERGE_TO_TOP_WIDTH(GRADIENT_MERGE_TO_TOP_WIDTH)
) Backward_top_controller_inst
(
    .clk(clk),
    .rst_n(rst_n),

    // Testbench와 연결되는 신호
    .backward_start(backward_start),
    .backward_ready(backward_ready),
    .backward_done(backward_done),

    .W_in(W_in),
    .H_in(H_in),
    
    .base_address(base_address),


    // Block Controller와 연결되는 신호
    // .block_gaussian_range(block_gaussian_range),

    .Block_data_ready(Block_data_ready),
    .gradient_value_valid(gradient_value_valid),
    
    .Block_data_done(Block_data_done),
    .gradient_value_ready(gradient_value_ready),

    .W_out(W),
    .H_out(H),
    .block_id_out(block_id_from_top_control_to_block_control),

    .block_gaussian_range_out(block_gaussian_range_out),

    // AXI4 BRAM 
    .s_aresetn(s_aresetn),

     // Gaussian Range BRAM
     .range_rsta_busy(range_rsta_busy),
     .range_rstb_busy(range_rstb_busy),
     .range_s_axi_awid(range_s_axi_awid),
     .range_s_axi_awaddr(range_s_axi_awaddr),
     .range_s_axi_awlen(range_s_axi_awlen),
     .range_s_axi_awsize(range_s_axi_awsize),
     .range_s_axi_awburst(range_s_axi_awburst),
     .range_s_axi_awvalid(range_s_axi_awvalid),
     .range_s_axi_awready(range_s_axi_awready),

     .range_s_axi_wdata(range_s_axi_wdata),
     .range_s_axi_wstrb(range_s_axi_wstrb),
     .range_s_axi_wlast(range_s_axi_wlast),
     .range_s_axi_wvalid(range_s_axi_wvalid),
     .range_s_axi_wready(range_s_axi_wready),

     .range_s_axi_bid(range_s_axi_bid),
     .range_s_axi_bresp(range_s_axi_bresp),
     .range_s_axi_bvalid(range_s_axi_bvalid),
     .range_s_axi_bready(range_s_axi_bready),

     .range_s_axi_arid(range_s_axi_arid),
     .range_s_axi_araddr(range_s_axi_araddr),
     .range_s_axi_arlen(range_s_axi_arlen),
     .range_s_axi_arsize(range_s_axi_arsize),
     .range_s_axi_arburst(range_s_axi_arburst),
     .range_s_axi_arvalid(range_s_axi_arvalid),
     .range_s_axi_arready(range_s_axi_arready),

     .range_s_axi_rid(range_s_axi_rid),
     .range_s_axi_rdata(range_s_axi_rdata),
     .range_s_axi_rresp(range_s_axi_rresp),
     .range_s_axi_rlast(range_s_axi_rlast),
     .range_s_axi_rvalid(range_s_axi_rvalid),
     .range_s_axi_rready(range_s_axi_rready),

     // Point List BRAM
     .point_list_rsta_busy(point_list_rsta_busy),
     .point_list_rstb_busy(point_list_rstb_busy),

     .point_list_s_axi_awid(point_list_s_axi_awid),
     .point_list_s_axi_awaddr(point_list_s_axi_awaddr),
     .point_list_s_axi_awlen(point_list_s_axi_awlen),
     .point_list_s_axi_awsize(point_list_s_axi_awsize),
     .point_list_s_axi_awburst(point_list_s_axi_awburst),
     .point_list_s_axi_awvalid(point_list_s_axi_awvalid),
     .point_list_s_axi_awready(point_list_s_axi_awready),

     .point_list_s_axi_wdata(point_list_s_axi_wdata),
     .point_list_s_axi_wstrb(point_list_s_axi_wstrb),
     .point_list_s_axi_wlast(point_list_s_axi_wlast),
     .point_list_s_axi_wvalid(point_list_s_axi_wvalid),
     .point_list_s_axi_wready(point_list_s_axi_wready),

     .point_list_s_axi_bid(point_list_s_axi_bid),
     .point_list_s_axi_bresp(point_list_s_axi_bresp),
     .point_list_s_axi_bvalid(point_list_s_axi_bvalid),
     .point_list_s_axi_bready(point_list_s_axi_bready),

     .point_list_s_axi_arid(point_list_s_axi_arid),
     .point_list_s_axi_araddr(point_list_s_axi_araddr),
     .point_list_s_axi_arlen(point_list_s_axi_arlen),
     .point_list_s_axi_arsize(point_list_s_axi_arsize),
     .point_list_s_axi_arburst(point_list_s_axi_arburst),
     .point_list_s_axi_arvalid(point_list_s_axi_arvalid),
     .point_list_s_axi_arready(point_list_s_axi_arready),

     .point_list_s_axi_rid(point_list_s_axi_rid),
     .point_list_s_axi_rdata(point_list_s_axi_rdata),
     .point_list_s_axi_rresp(point_list_s_axi_rresp),
     .point_list_s_axi_rlast(point_list_s_axi_rlast),
     .point_list_s_axi_rvalid(point_list_s_axi_rvalid),
     .point_list_s_axi_rready(point_list_s_axi_rready),

     // Gaussian
     .gaussian_rsta_busy(gaussian_rsta_busy),
     .gaussian_rstb_busy(gaussian_rstb_busy),

     .gaussian_s_axi_awid(gaussian_s_axi_awid),
     .gaussian_s_axi_awaddr(gaussian_s_axi_awaddr),
     .gaussian_s_axi_awlen(gaussian_s_axi_awlen),
     .gaussian_s_axi_awsize(gaussian_s_axi_awsize),
     .gaussian_s_axi_awburst(gaussian_s_axi_awburst),
     .gaussian_s_axi_awvalid(gaussian_s_axi_awvalid),
     .gaussian_s_axi_awready(gaussian_s_axi_awready),

     .gaussian_s_axi_wdata(gaussian_s_axi_wdata),
     .gaussian_s_axi_wstrb(gaussian_s_axi_wstrb),
     .gaussian_s_axi_wlast(gaussian_s_axi_wlast),
     .gaussian_s_axi_wvalid(gaussian_s_axi_wvalid),
     .gaussian_s_axi_wready(gaussian_s_axi_wready),

     .gaussian_s_axi_bid(gaussian_s_axi_bid),
     .gaussian_s_axi_bresp(gaussian_s_axi_bresp),
     .gaussian_s_axi_bvalid(gaussian_s_axi_bvalid),
     .gaussian_s_axi_bready(gaussian_s_axi_bready),

     .gaussian_s_axi_arid(gaussian_s_axi_arid),
     .gaussian_s_axi_araddr(gaussian_s_axi_araddr),
     .gaussian_s_axi_arlen(gaussian_s_axi_arlen),
     .gaussian_s_axi_arsize(gaussian_s_axi_arsize),
     .gaussian_s_axi_arburst(gaussian_s_axi_arburst),
     .gaussian_s_axi_arvalid(gaussian_s_axi_arvalid),
     .gaussian_s_axi_arready(gaussian_s_axi_arready),

     .gaussian_s_axi_rid(gaussian_s_axi_rid),
    //  .gaussian_s_axi_rdata(gaussian_s_axi_rdata),
     .gaussian_s_axi_rresp(gaussian_s_axi_rresp),
     .gaussian_s_axi_rlast(gaussian_s_axi_rlast),
     .gaussian_s_axi_rready(gaussian_s_axi_rready),
     .gaussian_s_axi_rvalid(gaussian_s_axi_rvalid),

     // Pixel
     .pixel_rsta_busy(pixel_rsta_busy),
     .pixel_rstb_busy(pixel_rstb_busy),

     .pixel_s_axi_awid(pixel_s_axi_awid),
     .pixel_s_axi_awaddr(pixel_s_axi_awaddr),
     .pixel_s_axi_awlen(pixel_s_axi_awlen),
     .pixel_s_axi_awsize(pixel_s_axi_awsize),
     .pixel_s_axi_awburst(pixel_s_axi_awburst),
     .pixel_s_axi_awvalid(pixel_s_axi_awvalid),
     .pixel_s_axi_awready(pixel_s_axi_awready),

     .pixel_s_axi_wdata(pixel_s_axi_wdata),
     .pixel_s_axi_wstrb(pixel_s_axi_wstrb),
     .pixel_s_axi_wlast(pixel_s_axi_wlast),
     .pixel_s_axi_wvalid(pixel_s_axi_wvalid),
     .pixel_s_axi_wready(pixel_s_axi_wready),

     .pixel_s_axi_bid(pixel_s_axi_bid),
     .pixel_s_axi_bresp(pixel_s_axi_bresp),
     .pixel_s_axi_bvalid(pixel_s_axi_bvalid),
     .pixel_s_axi_bready(pixel_s_axi_bready),

     .pixel_s_axi_arid(pixel_s_axi_arid),
     .pixel_s_axi_araddr(pixel_s_axi_araddr),
     .pixel_s_axi_arlen(pixel_s_axi_arlen),
     .pixel_s_axi_arsize(pixel_s_axi_arsize),
     .pixel_s_axi_arburst(pixel_s_axi_arburst),
     .pixel_s_axi_arvalid(pixel_s_axi_arvalid),
     .pixel_s_axi_arready(pixel_s_axi_arready),

     .pixel_s_axi_rid(pixel_s_axi_rid),
     .pixel_s_axi_rdata(pixel_s_axi_rdata),
     .pixel_s_axi_rresp(pixel_s_axi_rresp),
     .pixel_s_axi_rlast(pixel_s_axi_rlast),
     .pixel_s_axi_rvalid(pixel_s_axi_rvalid),
     .pixel_s_axi_rready(pixel_s_axi_rready),

     // Gradient
     .gradient_s_axi_awid(gradient_s_axi_awid),
     .gradient_s_axi_awaddr(gradient_s_axi_awaddr),
     .gradient_s_axi_awlen(gradient_s_axi_awlen),
     .gradient_s_axi_awsize(gradient_s_axi_awsize),
     .gradient_s_axi_awburst(gradient_s_axi_awburst),
     .gradient_s_axi_awvalid(gradient_s_axi_awvalid),
     .gradient_s_axi_awready(gradient_s_axi_awready),

     .gradient_s_axi_wdata(gradient_s_axi_wdata),
     .gradient_s_axi_wstrb(gradient_s_axi_wstrb),
     .gradient_s_axi_wlast(gradient_s_axi_wlast),
     .gradient_s_axi_wvalid(gradient_s_axi_wvalid),
     .gradient_s_axi_wready(gradient_s_axi_wready),

     .gradient_s_axi_bid(gradient_s_axi_bid),
     .gradient_s_axi_bresp(gradient_s_axi_bresp),
     .gradient_s_axi_bvalid(gradient_s_axi_bvalid),
     .gradient_s_axi_bready(gradient_s_axi_bready),

     .gradient_s_axi_arid(gradient_s_axi_arid),
     .gradient_s_axi_araddr(gradient_s_axi_araddr),
     .gradient_s_axi_arlen(gradient_s_axi_arlen),
     .gradient_s_axi_arsize(gradient_s_axi_arsize),
     .gradient_s_axi_arburst(gradient_s_axi_arburst),
     .gradient_s_axi_arvalid(gradient_s_axi_arvalid),
     .gradient_s_axi_arready(gradient_s_axi_arready),

     .gradient_s_axi_rid(gradient_s_axi_rid),
     .gradient_s_axi_rdata(gradient_s_axi_rdata),
     .gradient_s_axi_rresp(gradient_s_axi_rresp),
     .gradient_s_axi_rlast(gradient_s_axi_rlast),
     .gradient_s_axi_rvalid(gradient_s_axi_rvalid),
     .gradient_s_axi_rready(gradient_s_axi_rready),
     
    // Cache SRAM

     // Gaussian
    .write_address_to_gaussian_SRAM(write_address_to_gaussian_SRAM),
    .Gaussian_SRAM_WEB(Gaussian_SRAM_WEB),

     // Pixel
    .write_address_to_pixel_SRAM(write_address_to_pixel_SRAM),
    .Pixel_SRAM_WEB(Pixel_SRAM_WEB),

     // Gradient

    .push_to_Top_FIFO(push_to_Top_FIFO),
    .gradient_merge_to_Top_FIFO(gradient_merge_to_Top_FIFO),

    .Gradient_SRAM_REB_from_Top_control(Gradient_SRAM_REB_from_Top_control),
    .gradient_id_to_SRAM_from_Top_control(gradient_id_to_SRAM_from_Top_control),

    .Gradient_SRAM_WEB_from_Top_control(Gradient_SRAM_WEB_from_Top_control),

    .gaussian_ID_address_to_point_list_SRAM(gaussian_ID_address_to_point_list_SRAM),
    .gaussian_ID_to_point_list_SRAM(gaussian_ID_to_point_list_SRAM),
    .Point_list_WEB(Point_list_WEB),
    

    .gaussian_ID_read_address_point_list_SRAM(gaussian_ID_read_address_point_list_SRAM),
    .gaussian_ID_from_point_list_SRAM(gaussian_ID_from_point_list_SRAM),
    .Point_list_REB(Point_list_REB)
);


    Backward_Block_controller_pipelining_controller #(
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
        // .gradient_data_done(gradient_data_done),

        .W_in(W),
        .H_in(H),
        .block_id_in(block_id_from_top_control_to_block_control),

        // .last_gaussian_index_in(last_gaussian_index_in),

        .Block_data_ready(Block_data_ready),
        .gradient_value_valid(gradient_value_valid),
        // .gradient_value_done(gradient_value_done),

        .stall_to_controller_from_rasterizer(stall_to_controller_from_rasterizer),

        .stall_to_rasterizer_to_controller(stall_to_rasterizer_to_controller),
        
        .stall_to_rasterizer_from_controller(stall_backpressure_from_controller),

        
        
        .last_input_done_from_rasterizer(last_input_done_from_rasterizer),
        .last_input_done_from_gradient_merge(last_input_done_from_gradient_merge),

        .rasterizer_FIFO_pop_valid_in(FIFO_pop_valid_in),
        .rasterizer_FIFO_pop_ready_out(FIFO_pop_ready_out),

        .i_valid(i_valid),
        .gaussian_id_to_rasterizer(gaussian_id_to_rasterizer),
        .gaussian_color_to_rasterizer(gaussian_color_to_rasterizer),
        .gaussian_depth_to_rasterizer(gaussian_depth_to_rasterizer),
        .mean2D_to_rasterizer(mean2D_to_rasterizer),
        .conic_opacity_to_rasterizer(conic_opacity_to_rasterizer),
        .last_input_done_to_rasterizer(last_input_done_to_rasterizer),
        
        

        .start(start),

        .W(W_to_rasterizer),
        .H(H_to_rasterizer),
        .block_id(block_id),
        .pixel_id(pixel_id_current),

        .T_first_current(T_first_current),
        .dL_dpixel_current(dL_dpixel_current),
        .dL_dpixel_depth_current(dL_dpixel_depth_current),
        // .pixel_id_current(pixel_id_current),

        .gaussian_color_from_SRAM(gaussian_color_from_SRAM),
        .gaussian_depth_from_SRAM(gaussian_depth_from_SRAM),
        .mean2D_from_SRAM(mean2D_from_SRAM),
        .conic_opacity_from_SRAM(conic_opacity_from_SRAM),

        .gaussian_id_to_SRAM(gaussian_id_to_SRAM),

        // .Read_address_to_Gaussian_SRAM(Read_address_to_Gaussian_SRAM),
        .REB_to_gaussian_SRAM(REB_to_gaussian_SRAM),

        .next_n_contrib_from_SRAM(next_n_contrib_from_SRAM),
        .next_T_first_from_SRAM(next_T_first_from_SRAM),
        .next_dL_dpixel_from_SRAM(next_dL_dpixel_from_SRAM),
        .next_dL_dpixel_depth_from_SRAM(next_dL_dpixel_depth_from_SRAM),

        .Read_address_to_Pixel_SRAM(Read_address_to_Pixel_SRAM),
        .REB_to_Pixel_SRAM(REB_to_Pixel_SRAM),

        .Read_address_from_rasterizer_to_gradient_SRAM(Read_address_before_add),

        .REB_to_gradient_SRAM(REB_to_gradient_SRAM),
        .WEB_to_gradient_SRAM(WEB_to_gradient_SRAM),

        .gradient_ID_used(gradient_ID_used),

        .Gradient_first_used_LUT(gradient_first_used_LUT)

        ,.last_input_done_and_data_zero(last_input_done_and_data_zero)
    );



    // Rasterizer & Gradient Merge
    Combined_Backward_Rasterizer_and_merge_pipelining_controller #(
    // Combined_Backward_Rasterizer_and_merge #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .exponent_bit(exponent_bit),
        .mantissa_bit(mantissa_bit),
        .precision(precision),
        .gaussian_inputs(gaussian_inputs),
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .First_FIFO_depth(4),
        .Last_FIFO_depth(4),
        .Banks(Banks)
    )
    Combined_Backward_Rasterizer_and_merge_inst (
        .clk(clk),
        .rst_n(rst_n),

        .i_valid(i_valid),

        .W(W_to_rasterizer),
        .H(H_to_rasterizer),

        .start(start),
        .dL_dpixel(dL_dpixel_current),
        .dL_dpixel_depth(dL_dpixel_depth_current),
        .T_first(T_first_current),

        .block_id(block_id),
        .pixel_id(pixel_id_current),

        .stall_backpressure(stall_backpressure_from_controller),

        .last_input(last_input_done_to_rasterizer),

        .mean2D(mean2D_to_rasterizer),
        .conic_opacity(conic_opacity_to_rasterizer),
        .gaussian_id_in(gaussian_id_to_rasterizer),
        .gaussian_color(gaussian_color_to_rasterizer),
        .gaussian_depth(gaussian_depth_to_rasterizer),

        .stall_to_controller(stall_to_controller_from_rasterizer),

        .stall_to_rasterizer_to_controller(stall_to_rasterizer_to_controller),

        .FIFO_pop_valid_in(FIFO_pop_valid_in),
        .FIFO_pop_ready_out(FIFO_pop_ready_out),

        .last_input_done_from_rasterizer(last_input_done_from_rasterizer),

        .last_input_done_from_gradient_merge(last_input_done_from_gradient_merge),


        .SRAM_data_in_to_Adder(SRAM_data_in_to_Adder),
        .FIFO_to_SRAM_data(FIFO_to_SRAM_data),
        .Read_address_before_add(Read_address_before_add),
        .Write_address_after_add(Write_address_after_add),

        .last_input_done_and_data_zero(last_input_done_and_data_zero)
    );



endmodule