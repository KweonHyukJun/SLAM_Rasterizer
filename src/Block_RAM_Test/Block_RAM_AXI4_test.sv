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

    output wire Gradient_rsta_busy,
    output wire Gradient_rstb_busy,

    input wire s_aresetn,

    // aw channel
    input wire [11:0] Gradient_s_axi_awid,
    input wire [23:0] Gradient_s_axi_awaddr,
    input wire [7:0] Gradient_s_axi_awlen,
    input wire [2:0] Gradient_s_axi_awsize,
    input wire [1:0] Gradient_s_axi_awburst,
    input wire Gradient_s_axi_awvalid,
    output wire Gradient_s_axi_awready,

    // w channel
    input wire [159:0] Gradient_s_axi_wdata, // 쓰는 데이터
    input wire [31:0] Gradient_s_axi_wstrb,
    input wire Gradient_s_axi_wlast,
    input wire Gradient_s_axi_wvalid,
    output wire Gradient_s_axi_wready,

    // b channel
    output wire [11:0] Gradient_s_axi_bid,
    output wire [1:0] Gradient_s_axi_bresp,
    output wire Gradient_s_axi_bvalid,
    input wire Gradient_s_axi_bready,

    // ar channel
    input wire [11:0] Gradient_s_axi_arid,
    input wire [23:0] Gradient_s_axi_araddr,
    input wire [7:0] Gradient_s_axi_arlen,
    input wire [2:0] Gradient_s_axi_arsize,
    input wire [1:0] Gradient_s_axi_arburst,
    input wire Gradient_s_axi_arvalid,
    output wire Gradient_s_axi_arready,

    // r channel
    output wire [11:0] Gradient_s_axi_rid,
    output wire [159:0] Gradient_s_axi_rdata, // 이게 읽어오는 데이터
    output wire [1:0] Gradient_s_axi_rresp,
    output wire Gradient_s_axi_rlast,
    output wire Gradient_s_axi_rvalid,
    input wire Gradient_s_axi_rready
);



    // DRAM operational BRAM
    Gradient_Block_RAM #()
    Gradient_Block_RAM_inst
    (
        .rsta_busy(Gradient_rsta_busy),
        .rstb_busy(Gradient_rstb_busy),
        
        .s_aclk(clk),
        .s_aresetn(rst_n),
        .s_axi_awid(Gradient_s_axi_awid), // write address id
        .s_axi_awaddr(Gradient_s_axi_awaddr), // write address
        .s_axi_awlen(Gradient_s_axi_awlen), // write address length  
        .s_axi_awsize(Gradient_s_axi_awsize), // write address size
        .s_axi_awburst(Gradient_s_axi_awburst), // write address burst
        .s_axi_awvalid(Gradient_s_axi_awvalid), // write address valid
        .s_axi_awready(Gradient_s_axi_awready), // write address ready

        .s_axi_wdata(Gradient_s_axi_wdata), // write data
        .s_axi_wstrb(Gradient_s_axi_wstrb), // write strobe
        .s_axi_wlast(Gradient_s_axi_wlast), // write last
        .s_axi_wvalid(Gradient_s_axi_wvalid), // write valid
        .s_axi_wready(Gradient_s_axi_wready), // write ready

        .s_axi_bid(Gradient_s_axi_bid), // write response id
        .s_axi_bresp(Gradient_s_axi_bresp), // write response
        .s_axi_bvalid(Gradient_s_axi_bvalid), // write response valid
        .s_axi_bready(Gradient_s_axi_bready), // write response ready

        .s_axi_arid(Gradient_s_axi_arid), // read address id
        .s_axi_araddr(Gradient_s_axi_araddr), // read address
        .s_axi_arlen(Gradient_s_axi_arlen), // read address length
        .s_axi_arsize(Gradient_s_axi_arsize), // read address size
        .s_axi_arburst(Gradient_s_axi_arburst), // read address burst
        .s_axi_arvalid(Gradient_s_axi_arvalid), // read address valid
        .s_axi_arready(Gradient_s_axi_arready),

        .s_axi_rid(Gradient_s_axi_rid),
        .s_axi_rdata(Gradient_s_axi_rdata),
        .s_axi_rresp(Gradient_s_axi_rresp),
        .s_axi_rlast(Gradient_s_axi_rlast),
        .s_axi_rvalid(Gradient_s_axi_rvalid),
        .s_axi_rready(Gradient_s_axi_rready)
    );

endmodule