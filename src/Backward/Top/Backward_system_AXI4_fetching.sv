
module Backward_system_AXI4_fetching #(
    parameter precision = 16,
    parameter mantissa_bit = 7,
    parameter exponent_bit = 8,
    parameter num_pixels = 16,
    parameter GID_bit = 12,
    parameter BLOCK_SIZE = 16,
    parameter WINDOW_SIZE = 32,
    parameter Banks = 16,
    parameter gaussian_inputs = 4,
    parameter GRADIENT_MERGE_TO_TOP_WIDTH = 11 * precision,
    parameter Gaussian_Range_Bit = 24
)
(
    input wire clk,
    input wire rst_n,

    input wire backward_start,
    output wire backward_ready,

    output wire backward_done,

    input wire [11:0] W_in,
    input wire [11:0] H_in
);


localparam GAUSSIAN_SRAM_DEPTH = 1 << GID_bit;
localparam PIXEL_SRAM_DEPTH = 1 << ($clog2(BLOCK_SIZE));

localparam GAUSSIAN_SRAM_WIDTH = 10 * precision;
localparam PIXEL_SRAM_WIDTH = 5 * precision + GID_bit;
localparam GRADIENT_MERGE_WIDTH = 11 * precision;

// Wire 

// 이거 두개 뺀값으로 넣어야 할듯?
wire [GID_bit-1:0] block_gaussian_range_out;

wire [11:0] W;
wire [11:0] H;

wire [15:0] block_id_from_top_control_to_block_control;
wire [15:0] block_id;

wire Block_data_ready;
wire gradient_value_valid;

wire Block_data_done;
wire gradient_value_ready;


wire [GID_bit-1:0] write_address_to_gaussian_SRAM [gaussian_inputs-1:0];
// assign write_address_to_gaussian_SRAM = gaussian_id_from_DDR;



wire [10 * precision -1:0] gaussian_data_from_SRAM [gaussian_inputs-1:0];

wire [3 * precision - 1:0] gaussian_color_from_SRAM [gaussian_inputs-1:0];
wire [precision - 1:0] gaussian_depth_from_SRAM [gaussian_inputs-1:0];
wire [(2 * precision)-1:0] mean2D_from_SRAM [gaussian_inputs-1:0];
wire [(4 * precision)-1:0] conic_opacity_from_SRAM [gaussian_inputs-1:0];
wire [GID_bit-1:0] gaussian_id_to_SRAM [gaussian_inputs-1:0];

wire Gaussian_SRAM_WEB [gaussian_inputs-1:0];


wire [$clog2(BLOCK_SIZE)-1:0] write_address_to_pixel_SRAM [num_pixels-1:0];


wire Pixel_SRAM_WEB [num_pixels-1:0];

wire push_to_Top_FIFO;
wire [GRADIENT_MERGE_TO_TOP_WIDTH-1:0] gradient_merge_to_Top_FIFO;

wire Gradient_SRAM_REB_from_Top_control [Banks-1:0];
wire [GID_bit-1:0] gradient_id_to_SRAM_from_Top_control [Banks-1:0];

wire Gradient_SRAM_WEB_from_Top_control [Banks-1:0];


wire [PIXEL_SRAM_WIDTH -1:0] pixel_data_from_SRAM [num_pixels-1:0];

wire [GID_bit-1:0] next_n_contrib_from_SRAM [num_pixels-1:0];
wire [precision-1:0] next_T_first_from_SRAM [num_pixels-1:0];
wire [(3 * precision)-1:0] next_dL_dpixel_from_SRAM [num_pixels-1:0];
wire [precision-1:0] next_dL_dpixel_depth_from_SRAM [num_pixels-1:0];

// Point List
wire [GID_bit-1:0] gaussian_ID_address_to_point_list_SRAM;
wire [Gaussian_Range_Bit-1:0] gaussian_ID_to_point_list_SRAM;
wire Point_list_WEB;

wire [GID_bit-1:0] gaussian_ID_read_address_point_list_SRAM;
wire [Gaussian_Range_Bit-1:0] gaussian_ID_from_point_list_SRAM;
wire Point_list_REB;

    

    // AXI4 Connection Wire


      // Gaussian Range BRAM
      wire range_rsta_busy;
      wire range_rstb_busy;

      wire [11:0] range_s_axi_awid;
      wire [23:0] range_s_axi_awaddr;
      wire [7:0] range_s_axi_awlen;
      wire [2:0] range_s_axi_awsize;
      wire [1:0] range_s_axi_awburst;
      wire range_s_axi_awvalid;
      wire range_s_axi_awready;

      // w channel
      wire [159:0] range_s_axi_wdata; // 쓰는 데이터
      wire [31:0] range_s_axi_wstrb;
      wire range_s_axi_wlast;
      wire range_s_axi_wvalid;
      wire range_s_axi_wready;

      // b channel
      wire [11:0] range_s_axi_bid;
      wire [1:0] range_s_axi_bresp;
      wire range_s_axi_bvalid;
      wire range_s_axi_bready;

      // ar channel
      wire [11:0] range_s_axi_arid;
      wire [23:0] range_s_axi_araddr;
      wire [7:0] range_s_axi_arlen;
      wire [2:0] range_s_axi_arsize;
      wire [1:0] range_s_axi_arburst;
      wire range_s_axi_arvalid;
      wire range_s_axi_arready;

      // r channel
      wire [11:0] range_s_axi_rid;
      wire [159:0] range_s_axi_rdata; // 이게 읽어오는 데이터
      wire [1:0] range_s_axi_rresp;
      wire range_s_axi_rlast;
      wire range_s_axi_rvalid;
      wire range_s_axi_rready;

    
      // Point List BRAM
      wire point_list_rsta_busy;
      wire point_list_rstb_busy;

      wire [11:0] point_list_s_axi_awid;
      wire [13:0] point_list_s_axi_awaddr;
      wire [7:0] point_list_s_axi_awlen;
      wire [2:0] point_list_s_axi_awsize;
      wire [1:0] point_list_s_axi_awburst;
      wire point_list_s_axi_awvalid;
      wire point_list_s_axi_awready;

      // w channel
      wire [159:0] point_list_s_axi_wdata;
      wire [31:0] point_list_s_axi_wstrb;
      wire point_list_s_axi_wlast;
      wire point_list_s_axi_wvalid;
      wire point_list_s_axi_wready;

      // b channel
      wire [11:0] point_list_s_axi_bid;
      wire [1:0] point_list_s_axi_bresp;
      wire point_list_s_axi_bvalid;
      wire point_list_s_axi_bready;

      // ar channel
      wire [11:0] point_list_s_axi_arid;
      wire [13:0] point_list_s_axi_araddr;
      wire [7:0] point_list_s_axi_arlen;
      wire [2:0] point_list_s_axi_arsize;
      wire [1:0] point_list_s_axi_arburst;
      wire point_list_s_axi_arvalid;
      wire point_list_s_axi_arready;

      // r channel
      wire [11:0] point_list_s_axi_rid;
      wire [159:0] point_list_s_axi_rdata;
      wire [1:0] point_list_s_axi_rresp;
      wire point_list_s_axi_rlast;
      wire point_list_s_axi_rvalid;
      wire point_list_s_axi_rready;
    
      // Gaussian BRAM
      wire gaussian_rsta_busy;
      wire gaussian_rstb_busy;

      wire [11:0] gaussian_s_axi_awid;
      wire [23:0] gaussian_s_axi_awaddr;
      wire [7:0] gaussian_s_axi_awlen;
      wire [2:0] gaussian_s_axi_awsize;
      wire [1:0] gaussian_s_axi_awburst;
      wire gaussian_s_axi_awvalid;
      wire gaussian_s_axi_awready;

      // w channel
      wire [159:0] gaussian_s_axi_wdata; // 쓰는 데이터
      wire [31:0] gaussian_s_axi_wstrb;
      wire gaussian_s_axi_wlast;
      wire gaussian_s_axi_wvalid;
      wire gaussian_s_axi_wready;

      // b channel
      wire [11:0] gaussian_s_axi_bid;
      wire [1:0] gaussian_s_axi_bresp;
      wire gaussian_s_axi_bvalid;
      wire gaussian_s_axi_bready;

      // ar channel
      wire [11:0] gaussian_s_axi_arid;
      wire [23:0] gaussian_s_axi_araddr;
      wire [7:0] gaussian_s_axi_arlen;
      wire [2:0] gaussian_s_axi_arsize;
      wire [1:0] gaussian_s_axi_arburst;
      wire gaussian_s_axi_arvalid;
      wire gaussian_s_axi_arready;

      // r channel
      wire [11:0] gaussian_s_axi_rid;
      wire [159:0] gaussian_s_axi_rdata; // 이게 읽어오는 데이터
      wire [1:0] gaussian_s_axi_rresp;
      wire gaussian_s_axi_rlast;
      wire gaussian_s_axi_rvalid;
      wire gaussian_s_axi_rready;

      // Pixel BRAM
      wire pixel_rsta_busy;
      wire pixel_rstb_busy;

      wire [11:0] pixel_s_axi_awid;
      wire [23:0] pixel_s_axi_awaddr;
      wire [7:0] pixel_s_axi_awlen;
      wire [2:0] pixel_s_axi_awsize;
      wire [1:0] pixel_s_axi_awburst;
      wire pixel_s_axi_awvalid;
      wire pixel_s_axi_awready;

      // w channel
      wire [91:0] pixel_s_axi_wdata; // 쓰는 데이터
      wire [31:0] pixel_s_axi_wstrb;
      wire pixel_s_axi_wlast;
      wire pixel_s_axi_wvalid;
      wire pixel_s_axi_wready;

      // b channel
      wire [11:0] pixel_s_axi_bid;
      wire [1:0] pixel_s_axi_bresp;
      wire pixel_s_axi_bvalid;
      wire pixel_s_axi_bready;

      // ar channel
      wire [11:0] pixel_s_axi_arid;
      wire [21:0] pixel_s_axi_araddr;
      wire [7:0] pixel_s_axi_arlen;
      wire [2:0] pixel_s_axi_arsize;
      wire [1:0] pixel_s_axi_arburst;
      wire pixel_s_axi_arvalid;
      wire pixel_s_axi_arready;

      // r channel
      wire [11:0] pixel_s_axi_rid;
      wire [91:0] pixel_s_axi_rdata; // 이게 읽어오는 데이터
      wire [1:0] pixel_s_axi_rresp;
      wire pixel_s_axi_rlast;
      wire pixel_s_axi_rvalid;
      wire pixel_s_axi_rready;

      // Gradient BRAM
      wire gradient_rsta_busy;
      wire gradient_rstb_busy;

      wire [11:0] gradient_s_axi_awid;
      wire [23:0] gradient_s_axi_awaddr;
      wire [7:0] gradient_s_axi_awlen;
      wire [2:0] gradient_s_axi_awsize;
      wire [1:0] gradient_s_axi_awburst;
      wire gradient_s_axi_awvalid;
      wire gradient_s_axi_awready;

      // w channel
      wire [159:0] gradient_s_axi_wdata; // 쓰는 데이터
      wire [31:0] gradient_s_axi_wstrb;
      wire gradient_s_axi_wlast;
      wire gradient_s_axi_wvalid;
      wire gradient_s_axi_wready;

      // b channel
      wire [11:0] gradient_s_axi_bid;
      wire [1:0] gradient_s_axi_bresp;
      wire gradient_s_axi_bvalid;
      wire gradient_s_axi_bready;

      // ar channel
      wire [11:0] gradient_s_axi_arid;
      wire [23:0] gradient_s_axi_araddr;
      wire [7:0] gradient_s_axi_arlen;
      wire [2:0] gradient_s_axi_arsize;
      wire [1:0] gradient_s_axi_arburst;
      wire gradient_s_axi_arvalid;
      wire gradient_s_axi_arready;

      // r channel
      wire [11:0] gradient_s_axi_rid;
      wire [175:0] gradient_s_axi_rdata; // 이게 읽어오는 데이터
      wire [1:0] gradient_s_axi_rresp;
      wire gradient_s_axi_rlast;
      wire gradient_s_axi_rvalid;
      wire gradient_s_axi_rready;

// FF Register






// Comb Register
reg push_to_Top_FIFO_reg;
reg [GRADIENT_MERGE_TO_TOP_WIDTH-1:0] gradient_merge_to_Top_FIFO_reg;

reg [GID_bit-1:0] gradient_id_to_SRAM_from_Top_control_reg;


// Gradient SRAM reseting or writing singals
// REB 한 후 다음 사이클에 0 처리 때려넣으면 되는거 아닌가?
reg [GID_bit-1:0] gradient_SRAM_write_address_from_Top [Banks-1:0];
reg gradient_SRAM_WEB_from_Top [Banks-1:0];

wire [GID_bit-1:0] gradient_SRAM_write_address [Banks-1:0];
wire gradient_SRAM_WEB [Banks-1:0];

reg REB_to_gradient_SRAM_from_Top_control_before [Banks-1:0];
// reg REB_to_gradient_SRAM_from_Block_control_before [Banks-1:0];

wire gradient_SRAM_REB [Banks-1:0];

wire [GAUSSIAN_SRAM_DEPTH-1:0] gradient_first_used_LUT;

wire last_input_done_and_data_zero [Banks-1:0];



wire [GRADIENT_MERGE_WIDTH-1:0] FIFO_to_SRAM_data [Banks-1:0];
wire [GRADIENT_MERGE_WIDTH-1:0] INPUT_DATA_TO_GRADIENT_SRAM [Banks-1:0];

wire [GRADIENT_MERGE_WIDTH-1:0] SRAM_data_in_to_Adder [Banks-1:0];

wire [GID_bit-1:0] Read_address_before_add [Banks-1:0];
wire [GID_bit-1:0] Write_address_after_add [Banks-1:0];

wire [GID_bit-1:0] gradient_SRAM_read_address [Banks-1:0];

wire [GRADIENT_MERGE_WIDTH-1:0] SRAM_data_out [Banks-1:0];

wire gradient_ID_used [Banks-1:0];

wire FIFO_pop_valid_in [Banks-1:0];
wire FIFO_pop_ready_out [Banks-1:0];


wire last_input_already_sent_by_zero_n_contrib [Banks-1:0];

// To SRAM

    // Gaussian SRAM
    wire [GID_bit-1:0] Read_address_to_Gaussian_SRAM [gaussian_inputs-1:0];
    wire REB_to_gaussian_SRAM [gaussian_inputs-1:0];

    // Pixel SRAM
    // wire [2 * $clog2(num_pixels) - 1:0] Read_address_to_Pixel_SRAM [num_pixels-1:0];
    wire [$clog2(num_pixels) - 1:0] Read_address_to_Pixel_SRAM [num_pixels-1:0];
    wire REB_to_Pixel_SRAM [num_pixels-1:0];

    // Gradient SRAM
    wire REB_to_gradient_SRAM [Banks-1:0];
    wire WEB_to_gradient_SRAM [Banks-1:0];

// To Block controller

wire stall_to_controller_from_rasterizer [num_pixels-1:0];
wire last_input_done_from_rasterizer [num_pixels-1:0];
wire last_input_done_from_gradient_merge [Banks-1:0];

wire s_aresetn;

wire stall_to_rasterizer_to_controller;


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
    wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_current [num_pixels-1:0];
    wire stall_backpressure_from_controller;



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

        .W_in(W_in),
        .H_in(H_in),
        .block_id_in(block_id_from_top_control_to_block_control),

        .last_gaussian_index_in(last_gaussian_index_in),

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

        .W(W),
        .H(H),
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


// AXI4 BRAM

    // Gaussian Range BRAM
    // 0번 ~ 한 1200 2번뽑기 싫은뎅....
    // 얘는 범위 + 지맘대로인 Gaussian을 가져와야하는거고 막 0x6884 이딴거를 가져와야하는거니까
    // 0 ~ 9999 : Block (Tile)의 시작 12bit / 끝(직전) 12bit
    // 10000 ~ 500000 (잠정) Gaussian ID 지정 24bit (8.4M, 840만 공간 저장 가능)
    
    Gaussian_Range_Block_RAM #()
    Gaussian_Range_BRAM_inst
    (
        .rsta_busy(range_rsta_busy),
        .rstb_busy(range_rstb_busy),

        .s_aresetn(rst_n),
        .s_aclk(clk),

        .s_axi_awid(range_s_axi_awid),
        .s_axi_awaddr(range_s_axi_awaddr),
        .s_axi_awlen(range_s_axi_awlen),
        .s_axi_awsize(range_s_axi_awsize),
        .s_axi_awburst(range_s_axi_awburst),
        .s_axi_awvalid(range_s_axi_awvalid),
        .s_axi_awready(range_s_axi_awready),

        .s_axi_wdata(range_s_axi_wdata),
        .s_axi_wstrb(range_s_axi_wstrb),    
        .s_axi_wlast(range_s_axi_wlast),
        .s_axi_wvalid(range_s_axi_wvalid),
        .s_axi_wready(range_s_axi_wready),

        .s_axi_bid(range_s_axi_bid),
        .s_axi_bresp(range_s_axi_bresp),
        .s_axi_bvalid(range_s_axi_bvalid),
        .s_axi_bready(range_s_axi_bready),

        .s_axi_arid(range_s_axi_arid),
        .s_axi_araddr(range_s_axi_araddr),
        .s_axi_arlen(range_s_axi_arlen),    
        .s_axi_arsize(range_s_axi_arsize),
        .s_axi_arburst(range_s_axi_arburst),
        .s_axi_arvalid(range_s_axi_arvalid),
        .s_axi_arready(range_s_axi_arready),

        .s_axi_rid(range_s_axi_rid),
        .s_axi_rdata(range_s_axi_rdata),
        .s_axi_rresp(range_s_axi_rresp),
        .s_axi_rlast(range_s_axi_rlast),
        .s_axi_rvalid(range_s_axi_rvalid),
        .s_axi_rready(range_s_axi_rready)
    );


    Point_list_Block_RAM #()
    Point_list_BRAM_inst
    (
        .rsta_busy(point_list_rsta_busy),
        .rstb_busy(point_list_rstb_busy),

        .s_aresetn(rst_n),
        .s_aclk(clk),

        .s_axi_awid(point_list_s_axi_awid),
        .s_axi_awaddr(point_list_s_axi_awaddr),
        .s_axi_awlen(point_list_s_axi_awlen),
        .s_axi_awsize(point_list_s_axi_awsize),
        .s_axi_awburst(point_list_s_axi_awburst),
        .s_axi_awvalid(point_list_s_axi_awvalid),
        .s_axi_awready(point_list_s_axi_awready),

        .s_axi_wdata(point_list_s_axi_wdata),
        .s_axi_wstrb(point_list_s_axi_wstrb),    
        .s_axi_wlast(point_list_s_axi_wlast),
        .s_axi_wvalid(point_list_s_axi_wvalid),
        .s_axi_wready(point_list_s_axi_wready),

        .s_axi_bid(point_list_s_axi_bid),
        .s_axi_bresp(point_list_s_axi_bresp),
        .s_axi_bvalid(point_list_s_axi_bvalid),
        .s_axi_bready(point_list_s_axi_bready),

        .s_axi_arid(point_list_s_axi_arid),
        .s_axi_araddr(point_list_s_axi_araddr),
        .s_axi_arlen(point_list_s_axi_arlen),    
        .s_axi_arsize(point_list_s_axi_arsize),
        .s_axi_arburst(point_list_s_axi_arburst),
        .s_axi_arvalid(point_list_s_axi_arvalid),
        .s_axi_arready(point_list_s_axi_arready),

        .s_axi_rid(point_list_s_axi_rid),
        .s_axi_rdata(point_list_s_axi_rdata),
        .s_axi_rresp(point_list_s_axi_rresp),
        .s_axi_rlast(point_list_s_axi_rlast),
        .s_axi_rvalid(point_list_s_axi_rvalid),
        .s_axi_rready(point_list_s_axi_rready)
    );




    // Gaussian Data

    // DRAM operational BRAM
    // 0번 Gaussian ~ 마지막 Gaussian 달려있는거고
    Gaussian_Block_RAM #()
    Gaussian_Block_RAM_inst
    (
        .rsta_busy(gaussian_rsta_busy),
        .rstb_busy(gaussian_rstb_busy),
        
        .s_aclk(clk),
        .s_aresetn(rst_n),
        .s_axi_awid(gaussian_s_axi_awid), // write address id
        .s_axi_awaddr(gaussian_s_axi_awaddr), // write address
        .s_axi_awlen(gaussian_s_axi_awlen), // write address length  
        .s_axi_awsize(gaussian_s_axi_awsize), // write address size
        .s_axi_awburst(gaussian_s_axi_awburst), // write address burst
        .s_axi_awvalid(gaussian_s_axi_awvalid), // write address valid
        .s_axi_awready(gaussian_s_axi_awready), // write address ready

        .s_axi_wdata(gaussian_s_axi_wdata), // write data
        .s_axi_wstrb(gaussian_s_axi_wstrb), // write strobe
        .s_axi_wlast(gaussian_s_axi_wlast), // write last
        .s_axi_wvalid(gaussian_s_axi_wvalid), // write valid
        .s_axi_wready(gaussian_s_axi_wready), // write ready

        .s_axi_bid(gaussian_s_axi_bid), // write response id
        .s_axi_bresp(gaussian_s_axi_bresp), // write response
        .s_axi_bvalid(gaussian_s_axi_bvalid), // write response valid
        .s_axi_bready(gaussian_s_axi_bready), // write response ready

        .s_axi_arid(gaussian_s_axi_arid), // read address id
        .s_axi_araddr(gaussian_s_axi_araddr), // read address
        .s_axi_arlen(gaussian_s_axi_arlen), // read address length
        .s_axi_arsize(gaussian_s_axi_arsize), // read address size
        .s_axi_arburst(gaussian_s_axi_arburst), // read address burst
        .s_axi_arvalid(gaussian_s_axi_arvalid), // read address valid
        .s_axi_arready(gaussian_s_axi_arready),

        .s_axi_rid(gaussian_s_axi_rid),
        .s_axi_rdata(gaussian_s_axi_rdata),
        .s_axi_rresp(gaussian_s_axi_rresp),
        .s_axi_rlast(gaussian_s_axi_rlast),
        .s_axi_rvalid(gaussian_s_axi_rvalid),
        .s_axi_rready(gaussian_s_axi_rready)
    );


    // Pixel Data
    Pixel_Block_RAM #()
    Pixel_Block_RAM_inst
    (
        .rsta_busy(pixel_rsta_busy),
        .rstb_busy(pixel_rstb_busy),
        
        .s_aclk(clk),
        .s_aresetn(rst_n),
        .s_axi_awid(pixel_s_axi_awid), // write address id
        .s_axi_awaddr(pixel_s_axi_awaddr), // write address
        .s_axi_awlen(pixel_s_axi_awlen), // write address length  
        .s_axi_awsize(pixel_s_axi_awsize), // write address size
        .s_axi_awburst(pixel_s_axi_awburst), // write address burst
        .s_axi_awvalid(pixel_s_axi_awvalid), // write address valid
        .s_axi_awready(pixel_s_axi_awready), // write address ready

        .s_axi_wdata(pixel_s_axi_wdata), // write data
        .s_axi_wstrb(pixel_s_axi_wstrb), // write strobe
        .s_axi_wlast(pixel_s_axi_wlast), // write last
        .s_axi_wvalid(pixel_s_axi_wvalid), // write valid
        .s_axi_wready(pixel_s_axi_wready), // write ready

        .s_axi_bid(pixel_s_axi_bid), // write response id
        .s_axi_bresp(pixel_s_axi_bresp), // write response
        .s_axi_bvalid(pixel_s_axi_bvalid), // write response valid
        .s_axi_bready(pixel_s_axi_bready), // write response ready

        .s_axi_arid(pixel_s_axi_arid), // read address id
        .s_axi_araddr(pixel_s_axi_araddr), // read address
        .s_axi_arlen(pixel_s_axi_arlen), // read address length
        .s_axi_arsize(pixel_s_axi_arsize), // read address size
        .s_axi_arburst(pixel_s_axi_arburst), // read address burst
        .s_axi_arvalid(pixel_s_axi_arvalid), // read address valid
        .s_axi_arready(pixel_s_axi_arready),

        .s_axi_rid(pixel_s_axi_rid),
        .s_axi_rdata(pixel_s_axi_rdata),
        .s_axi_rresp(pixel_s_axi_rresp),
        .s_axi_rlast(pixel_s_axi_rlast),
        .s_axi_rvalid(pixel_s_axi_rvalid),
        .s_axi_rready(pixel_s_axi_rready)
    );




    // Gradient Data
    Gradient_Block_RAM #()
    Gradient_Block_RAM_inst
    (
        .rsta_busy(gradient_rsta_busy),
        .rstb_busy(gradient_rstb_busy),
        
        .s_aclk(clk),
        .s_aresetn(rst_n),
        .s_axi_awid(gradient_s_axi_awid), // write address id
        .s_axi_awaddr(gradient_s_axi_awaddr), // write address
        .s_axi_awlen(gradient_s_axi_awlen), // write address length  
        .s_axi_awsize(gradient_s_axi_awsize), // write address size
        .s_axi_awburst(gradient_s_axi_awburst), // write address burst
        .s_axi_awvalid(gradient_s_axi_awvalid), // write address valid
        .s_axi_awready(gradient_s_axi_awready), // write address ready

        .s_axi_wdata(gradient_s_axi_wdata), // write data
        .s_axi_wstrb(gradient_s_axi_wstrb), // write strobe
        .s_axi_wlast(gradient_s_axi_wlast), // write last
        .s_axi_wvalid(gradient_s_axi_wvalid), // write valid
        .s_axi_wready(gradient_s_axi_wready), // write ready

        .s_axi_bid(gradient_s_axi_bid), // write response id
        .s_axi_bresp(gradient_s_axi_bresp), // write response
        .s_axi_bvalid(gradient_s_axi_bvalid), // write response valid
        .s_axi_bready(gradient_s_axi_bready), // write response ready

        .s_axi_arid(gradient_s_axi_arid), // read address id
        .s_axi_araddr(gradient_s_axi_araddr), // read address
        .s_axi_arlen(gradient_s_axi_arlen), // read address length
        .s_axi_arsize(gradient_s_axi_arsize), // read address size
        .s_axi_arburst(gradient_s_axi_arburst), // read address burst
        .s_axi_arvalid(gradient_s_axi_arvalid), // read address valid
        .s_axi_arready(gradient_s_axi_arready),

        .s_axi_rid(gradient_s_axi_rid),
        .s_axi_rdata(gradient_s_axi_rdata),
        .s_axi_rresp(gradient_s_axi_rresp),
        .s_axi_rlast(gradient_s_axi_rlast),
        .s_axi_rvalid(gradient_s_axi_rvalid),
        .s_axi_rready(gradient_s_axi_rready)
    );





    genvar pix, gau;
    generate 
        for (gau = 0; gau < gaussian_inputs; gau = gau + 1) begin : Gaussian_SRAM_inst
            dp_ram #( .N(GAUSSIAN_SRAM_WIDTH), .W(GAUSSIAN_SRAM_DEPTH))
            Gaussian_SRAM_inst(
            .clk(clk),
                // rst_n 없는 신호임
            .rst_n(rst_n),

             // Write 는 Top에서 AXI4 BRAM 연결해야함
            .AA(write_address_to_gaussian_SRAM[gau]), // write address
            .D(gaussian_s_axi_rdata), // write data
            .WEB(Gaussian_SRAM_WEB[gau]), // write enable
            
            .AB(gaussian_id_to_SRAM[gau]), // read address
            .REB(REB_to_gaussian_SRAM[gau]), // read enable
            .Q(gaussian_data_from_SRAM[gau]) // read data
            );


            assign gaussian_color_from_SRAM[gau] = gaussian_data_from_SRAM[gau][10 * precision - 1:7 * precision];
            assign gaussian_depth_from_SRAM[gau] = gaussian_data_from_SRAM[gau][7 * precision - 1:6 * precision];
            assign mean2D_from_SRAM[gau] = gaussian_data_from_SRAM[gau][6 * precision - 1:4 * precision];
            assign conic_opacity_from_SRAM[gau] = gaussian_data_from_SRAM[gau][4* precision - 1:0];

        end
    endgenerate

    generate
        for (pix = 0; pix < num_pixels; pix = pix + 1) begin : Pixel_SRAM_inst
            dp_ram #( .N(PIXEL_SRAM_WIDTH), .W(PIXEL_SRAM_DEPTH))
            Pixel_SRAM_inst(
                .clk(clk),
                .rst_n(rst_n),

                 // Write 는 AXI4 BRAM에서 연결해서 처리
                // .AA(pixel_id_from_DDR[pix]), // write address
                .AA(write_address_to_pixel_SRAM[pix]), // write address
                .D(pixel_s_axi_rdata), // write data

                .WEB(Pixel_SRAM_WEB[pix]), // write enable


                .AB(Read_address_to_Pixel_SRAM[pix]), // read address
                .REB(REB_to_Pixel_SRAM[pix]), // read enable
                .Q(pixel_data_from_SRAM[pix]) // read data
            );

            // assign pixel_data_from_DDR[pix] = {dL_dpixel_from_DDR[pix], dL_dpixel_depth_from_DDR[pix], T_first_from_DDR[pix], n_contrib_from_DDR[pix]};

            assign next_dL_dpixel_from_SRAM[pix] = pixel_data_from_SRAM[pix][(5 * precision) + GID_bit - 1: (2 * precision) + GID_bit];
            assign next_dL_dpixel_depth_from_SRAM[pix] = pixel_data_from_SRAM[pix][(2 * precision) + GID_bit - 1: precision + GID_bit];
            assign next_T_first_from_SRAM[pix] = pixel_data_from_SRAM[pix][precision + GID_bit - 1:GID_bit];
            assign next_n_contrib_from_SRAM[pix] = pixel_data_from_SRAM[pix][GID_bit-1:0];
        end
    endgenerate

    dp_ram # (.N(Gaussian_Range_Bit), .W(1 << GID_bit))
    Point_list_SRAM_inst(
        .clk(clk),
        .rst_n(rst_n),

        .AA(gaussian_ID_address_to_point_list_SRAM),
        .D(gaussian_ID_to_point_list_SRAM),
        .WEB(Point_list_WEB),

        .AB(gaussian_ID_read_address_point_list_SRAM),
        .REB(Point_list_REB),
        .Q(gaussian_ID_from_point_list_SRAM)
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
        .WINDOW_SIZE(WINDOW_SIZE),
        .Banks(Banks)
    )
    Combined_Backward_Rasterizer_and_merge_inst (
        .clk(clk),
        .rst_n(rst_n),

        .i_valid(i_valid),

        .W(W),
        .H(H),

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


    // 이건 Raster module과 해서 추후 테스트 진행
    // 추가적으로 Block 데이터 처음 들어올 시 새거에 대한 컨트롤이 필요할듯?

    genvar m;
    generate

        assign push_to_Top_FIFO = push_to_Top_FIFO_reg;
        assign gradient_merge_to_Top_FIFO =  gradient_first_used_LUT[gradient_id_to_SRAM_from_Top_control_reg] ? gradient_merge_to_Top_FIFO_reg : 'h0;


        for (m = 0; m < Banks; m++) begin : Gradient_SRAM_inst

        assign gradient_SRAM_REB[m] = (REB_to_gradient_SRAM[m] && Gradient_SRAM_REB_from_Top_control[m]);

        // assign gradient_SRAM_read_address[m] = !Gradient_SRAM_REB_from_Top_control[m] ? gradient_id_to_SRAM_from_Top_control[m] >> $clog2(Banks) : 
        assign gradient_SRAM_read_address[m] = !Gradient_SRAM_REB_from_Top_control[m] ? gradient_id_to_SRAM_from_Top_control[m] >> $clog2(Banks) : 

                                                ( !REB_to_gradient_SRAM[m] ? Read_address_before_add[m] >> $clog2(Banks): 'h0);

        assign SRAM_data_in_to_Adder[m] = gradient_ID_used[m] ? SRAM_data_out[m] : 'h0;


        // Gradient Write 신호

        assign gradient_SRAM_WEB[m] = (WEB_to_gradient_SRAM[m] && gradient_SRAM_WEB_from_Top[m])
                                     && (Gradient_SRAM_WEB_from_Top_control[m]);
        assign gradient_SRAM_write_address[m] = !gradient_SRAM_WEB_from_Top[m] ? gradient_SRAM_write_address_from_Top[m] >> $clog2(Banks) :
                                                ( !WEB_to_gradient_SRAM[m] ? Write_address_after_add[m] >> $clog2(Banks) : 'h0);


        // assign INPUT_DATA_TO_GRADIENT_SRAM[m] = !gradient_SRAM_WEB_from_Top[m] ? 'h0 : 
        //                                         ( !WEB_to_gradient_SRAM[m] ? FIFO_to_SRAM_data[m] : 'h0);

        assign INPUT_DATA_TO_GRADIENT_SRAM[m] = !Gradient_SRAM_WEB_from_Top_control[m] ? 'h0 :( 
                                                !gradient_SRAM_WEB_from_Top[m] ? 'h0 : 
                                                ( !WEB_to_gradient_SRAM[m] ? FIFO_to_SRAM_data[m] : 'h0));

        // 이거 SRAM은 초기화 해야함
        dp_ram #( .N(GRADIENT_MERGE_WIDTH), .W(GAUSSIAN_SRAM_DEPTH) )
        Gradient_SRAM_inst(
            .clk(clk),
            // rst_n 없는 신호임
            .rst_n(rst_n),

            // .AA((Write_address_after_add[m] >> $clog2(Banks))), // write address
            // .D(FIFO_to_SRAM_data[m]), // write data
            // .WEB(WEB_to_gradient_SRAM[m]), // write enable

            .AA(gradient_SRAM_write_address[m]), // write address
            .D(INPUT_DATA_TO_GRADIENT_SRAM[m]), // write data
            .WEB(gradient_SRAM_WEB[m]), // write enable                

            .AB(gradient_SRAM_read_address[m]), // read address
            // .REB(REB_to_gradient_SRAM[m]), // read enable
            .REB(gradient_SRAM_REB[m]), // read enable
            .Q(SRAM_data_out[m]) // read data
        );

        end
    endgenerate


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            gradient_id_to_SRAM_from_Top_control_reg <= 'h0;
            for (int Bank = 0; Bank < Banks; Bank++) begin
                REB_to_gradient_SRAM_from_Top_control_before[Bank] <= 1'b1;

                gradient_SRAM_WEB_from_Top[Bank] <= 1'b1;
                gradient_SRAM_write_address_from_Top[Bank] <= 'h0;

            end
        end
        else begin
            gradient_id_to_SRAM_from_Top_control_reg <= gradient_id_to_SRAM_from_Top_control[0];

            for (int Bank = 0; Bank < Banks; Bank++) begin
                REB_to_gradient_SRAM_from_Top_control_before[Bank] <= Gradient_SRAM_REB_from_Top_control[Bank];

                gradient_SRAM_WEB_from_Top[Bank] <= Gradient_SRAM_REB_from_Top_control[Bank];
                gradient_SRAM_write_address_from_Top[Bank] <= gradient_id_to_SRAM_from_Top_control[0];
                
            end
        end
    end

    
    // combinational regitser

    always_comb begin
        push_to_Top_FIFO_reg = 0;
        gradient_merge_to_Top_FIFO_reg = 'h0;

        for (int Bank = 0; Bank < Banks; Bank++) begin
            if (!REB_to_gradient_SRAM_from_Top_control_before[Bank]) begin
                push_to_Top_FIFO_reg = 1'b1;
                gradient_merge_to_Top_FIFO_reg = SRAM_data_out[Bank];
            end
        end
    end





    // wire Top_fifo_push;
    // wire [11 * precision - 1:0] Top_fifo_push_data;

    // wire Top_fifo_pop;
    // wire [11 * precision - 1:0] Top_fifo_pop_data;

    // wire Top_fifo_full;
    // wire Top_fifo_empty;
    
    // assign Top_fifo_push = push_to_Top_FIFO && !Top_fifo_full;
    // assign Top_fifo_push_data = gradient_merge_to_Top_FIFO;

    


    
    // // BLock에서의 데이터를 

    // push_pop_FIFO
    // #(
    //     .FIFO_depth(3),
    //     .input_data_width(11 * precision),
    //     .output_data_width(11 * precision)
    // )

    // gradient_to_External_memory_FIFO_inst
    // (
    //     .clk(clk),
    //     .rst_n(rst_n),
        
    //     .push_data_in(Top_fifo_push_data),
    //     .push_valid_in(Top_fifo_push),

    //     .pop_valid_in(pop_valid_in),
    //     .pop_data_out(pop_data_out),

    //     .full_out(Top_fifo_full),
    //     .empty_out(Top_fifo_empty) 
    // );


endmodule

