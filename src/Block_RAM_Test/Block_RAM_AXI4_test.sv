module Block_RAM_AXI4_test

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

(
    input wire clk,
    input wire rst_n,

    // BRAM port 

    output wire gaussian_rsta_busy,
    output wire gaussian_rstb_busy,

    input wire s_aresetn,

    // aw channel
    input wire [3:0] gaussian_s_axi_awid,
    input wire [31:0] gaussian_s_axi_awaddr,
    input wire [7:0] gaussian_s_axi_awlen,
    input wire [2:0] gaussian_s_axi_awsize,
    input wire [1:0] gaussian_s_axi_awburst,
    input wire gaussian_s_axi_awvalid,
    output wire gaussian_s_axi_awready,

    // w channel
    input wire [255:0] gaussian_s_axi_wdata, // 쓰는 데이터
    input wire [3:0] gaussian_s_axi_wstrb,
    input wire gaussian_s_axi_wlast,
    input wire gaussian_s_axi_wvalid,
    output wire gaussian_s_axi_wready,

    // b channel
    output wire [3:0] gaussian_s_axi_bid,
    output wire [1:0] gaussian_s_axi_bresp,
    output wire gaussian_s_axi_bvalid,
    input wire gaussian_s_axi_bready,

    // ar channel
    input wire [3:0] gaussian_s_axi_arid,
    input wire [31:0] gaussian_s_axi_araddr,
    input wire [7:0] gaussian_s_axi_arlen,
    input wire [2:0] gaussian_s_axi_arsize,
    input wire [1:0] gaussian_s_axi_arburst,
    input wire gaussian_s_axi_arvalid,
    output wire gaussian_s_axi_arready,

    // r channel
    output wire [3:0] gaussian_s_axi_rid,
    output wire [255:0] gaussian_s_axi_rdata, // 이게 읽어오는 데이터
    output wire [1:0] gaussian_s_axi_rresp,
    output wire gaussian_s_axi_rlast,
    output wire gaussian_s_axi_rvalid,
    input wire gaussian_s_axi_rready
);



    // DRAM operational BRAM
    Gaussian_Block_RAM #()
    Gaussian_Block_RAM_inst
    (
        .rsta_busy(gaussian_rsta_busy),
        .rstb_busy(gaussian_rstb_busy),
        
        .s_aclk(clk),
        .s_aresetn(s_aresetn),
        .s_axi_awid(gaussian_s_axi_awid), // write address id
        .s_axi_awaddr(gaussian_s_axi_awaddr), // write address
        .s_axi_awlen(gaussian_s_axi_awlen), // write address length  
        .s_axi_awsize(gaussian_s_axi_awsize), // write address size
        .s_axi_awburst(gaussian_s_axi_awburst), // write address burst
        .s_axi_awvalid(gaussian_s_axi_awvalid), // write address valid
        .s_axi_awready(gaussian_s_axi_awready), // write address ready

        .s_axi_wdata(gaussian_s_axi_wdata),
        .s_axi_wstrb(gaussian_s_axi_wstrb),
        .s_axi_wlast(gaussian_s_axi_wlast),
        .s_axi_wvalid(gaussian_s_axi_wvalid),
        .s_axi_wready(gaussian_s_axi_wready),

        .s_axi_bid(gaussian_s_axi_bid),
        .s_axi_bresp(gaussian_s_axi_bresp),
        .s_axi_bvalid(gaussian_s_axi_bvalid),
        .s_axi_bready(gaussian_s_axi_bready),

        .s_axi_arid(gaussian_s_axi_arid),
        .s_axi_araddr(gaussian_s_axi_araddr),
        .s_axi_arlen(gaussian_s_axi_arlen),
        .s_axi_arsize(gaussian_s_axi_arsize),
        .s_axi_arburst(gaussian_s_axi_arburst),
        .s_axi_arvalid(gaussian_s_axi_arvalid),
        .s_axi_arready(gaussian_s_axi_arready),

        .s_axi_rid(gaussian_s_axi_rid),
        .s_axi_rdata(gaussian_s_axi_rdata),
        .s_axi_rresp(gaussian_s_axi_rresp),
        .s_axi_rlast(gaussian_s_axi_rlast),
        .s_axi_rvalid(gaussian_s_axi_rvalid),
        .s_axi_rready(gaussian_s_axi_rready)
    );

    // Pixel_Block_RAM #()
    // Pixel_Block_RAM_inst
    // (
    //     .rsta_busy(),
    //     .rstb_busy(),
        
    //     .s_aclk(clk),
    //     .s_aresetn(rst_n),
    //     .s_axi_awid(),
    //     .s_axi_awaddr(),
    //     .s_axi_awlen(),
    //     .s_axi_awsize(),
    //     .s_axi_awburst(),
    //     .s_axi_awvalid(),
    //     .s_axi_awready(),
    //     .s_axi_wdata(),
    //     .s_axi_wstrb(),
    //     .s_axi_wlast(),
    //     .s_axi_wvalid(),
    //     .s_axi_wready(),
    //     .s_axi_bid(),
    //     .s_axi_bresp(),
    //     .s_axi_bvalid(),
    //     .s_axi_bready(),
    //     .s_axi_arid(),
    //     .s_axi_araddr(),
    //     .s_axi_arlen(),
    //     .s_axi_arsize(),
    //     .s_axi_arburst(),
    //     .s_axi_arvalid(),
    //     .s_axi_arready(),
    //     .s_axi_rid(),
    //     .s_axi_rdata(),
    //     .s_axi_rresp(),
    //     .s_axi_rlast(),
    //     .s_axi_rvalid(),
    //     .s_axi_rready()        
    // );

    // Gradient_Block_RAM #()
    // Gradient_Block_RAM_inst
    // (
    //     .rsta_busy(),
    //     .rstb_busy(),
    //     .s_aclk(clk),
    //     .s_aresetn(rst_n),
    //     .s_axi_awid(),
    //     .s_axi_awaddr(),
    //     .s_axi_awlen(),
    //     .s_axi_awsize(),
    //     .s_axi_awburst(),
    //     .s_axi_awvalid(),
    //     .s_axi_awready(),
    //     .s_axi_wdata(),
    //     .s_axi_wstrb(),
    //     .s_axi_wlast(),
    //     .s_axi_wvalid(),
    //     .s_axi_wready(),
    //     .s_axi_bid(),
    //     .s_axi_bresp(),
    //     .s_axi_bvalid(),
    //     .s_axi_bready(),
    //     .s_axi_arid(),
    //     .s_axi_araddr(),
    //     .s_axi_arlen(),
    //     .s_axi_arsize(),
    //     .s_axi_arburst(),
    //     .s_axi_arvalid(),
    //     .s_axi_arready(),
    //     .s_axi_rid(),
    //     .s_axi_rdata(),
    //     .s_axi_rresp(),
    //     .s_axi_rlast(),
    //     .s_axi_rvalid(),
    //     .s_axi_rready()
    // );

endmodule