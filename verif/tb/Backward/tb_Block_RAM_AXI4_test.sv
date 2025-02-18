
`define MAX_MEMBER_SIZE 400000
// `define MAX_CLOCK_COUNT 2000000
`define MAX_CLOCK_COUNT 500

module tb_Block_RAM_AXI4_test ();

    integer max_clock_count = `MAX_CLOCK_COUNT;

    // input
    reg clk;
    reg rst_n;

    reg s_aresetn;

    // for R/V handshake

    wire [3:0] gaussian_s_axi_awid;
    wire [31:0] gaussian_s_axi_awaddr;
    wire [7:0] gaussian_s_axi_awlen;
    wire [2:0] gaussian_s_axi_awsize;
    wire [1:0] gaussian_s_axi_awburst;
    wire gaussian_s_axi_awvalid;

    wire [255:0] gaussian_s_axi_wdata;
    wire [3:0] gaussian_s_axi_wstrb;
    wire gaussian_s_axi_wlast;
    wire gaussian_s_axi_wvalid;
    
    wire [3:0] gaussian_s_axi_bid;
    wire [1:0] gaussian_s_axi_bresp;
    wire gaussian_s_axi_bready;

    wire [3:0] gaussian_s_axi_arid;
    wire [31:0] gaussian_s_axi_araddr;
    wire [7:0] gaussian_s_axi_arlen;
    wire [2:0] gaussian_s_axi_arsize;
    wire [1:0] gaussian_s_axi_arburst;
    wire gaussian_s_axi_arvalid;

    wire [3:0] gaussian_s_axi_rid;
    wire [255:0] gaussian_s_axi_rdata;
    wire [1:0] gaussian_s_axi_rresp;
    wire gaussian_s_axi_rlast;
    wire gaussian_s_axi_rready;
    

    // output

    // for R/V handshake
    wire gaussian_s_axi_awready;
    wire gaussian_s_axi_wready;
    wire gaussian_s_axi_bvalid;
    wire gaussian_s_axi_arready;
    wire gaussian_s_axi_rvalid;


    


    initial begin
        $fsdbDumpfile("../output_backward/backward_dump.fsdb");
        $fsdbDumpvars(0, tb_Block_RAM_AXI4_test, "+all");
    end
    // Instantiate the DUT (Device Under Test)
    Block_RAM_AXI4_test #() 
    Block_RAM_AXI4_test_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        .s_aresetn(s_aresetn),

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
        .gaussian_s_axi_rdata(gaussian_s_axi_rdata),
        .gaussian_s_axi_rresp(gaussian_s_axi_rresp),
        .gaussian_s_axi_rlast(gaussian_s_axi_rlast),
        .gaussian_s_axi_rvalid(gaussian_s_axi_rvalid),
        .gaussian_s_axi_rready(gaussian_s_axi_rready)
    );


    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == max_clock_count) $finish;
    end


    initial begin
        clk <= 1'b0;
        rst_n <= 1'b1;
        s_aresetn <= 1'b1;

        @ (posedge clk);
        @ (posedge clk);

        $finish;
    end




endmodule