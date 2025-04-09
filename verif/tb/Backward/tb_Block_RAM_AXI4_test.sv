
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

    wire [11:0] Gradient_s_axi_awid;
    wire [31:0] Gradient_s_axi_awaddr;
    wire [7:0] Gradient_s_axi_awlen;
    wire [2:0] Gradient_s_axi_awsize;
    wire [1:0] Gradient_s_axi_awburst;
    wire Gradient_s_axi_awvalid;

    wire [159:0] Gradient_s_axi_wdata;
    // wire [255:0] Gradient_s_axi_wdata;
    wire [3:0] Gradient_s_axi_wstrb;
    wire Gradient_s_axi_wlast;
    wire Gradient_s_axi_wvalid;
    
    wire [11:0] Gradient_s_axi_bid;
    wire [1:0] Gradient_s_axi_bresp;
    wire Gradient_s_axi_bready;

    wire [11:0] Gradient_s_axi_arid;
    wire [31:0] Gradient_s_axi_araddr;
    wire [7:0] Gradient_s_axi_arlen;
    wire [2:0] Gradient_s_axi_arsize;
    wire [1:0] Gradient_s_axi_arburst;
    wire Gradient_s_axi_arvalid;

    wire [11:0] Gradient_s_axi_rid;
    wire [159:0] Gradient_s_axi_rdata;
    // wire [255:0] Gradient_s_axi_rdata;
    wire [1:0] Gradient_s_axi_rresp;
    wire Gradient_s_axi_rlast;
    wire Gradient_s_axi_rready;
    

    // output

    // for R/V handshake
    wire Gradient_s_axi_awready;
    wire Gradient_s_axi_wready;
    wire Gradient_s_axi_bvalid;
    wire Gradient_s_axi_arready;
    wire Gradient_s_axi_rvalid;

    wire Gradient_rsta_busy;
    wire Gradient_rstb_busy;


    // internal signal
    reg testbench_start;

    parameter N_GAUSSIANS = 31985;
    parameter DUPLICATE_GAUSSIANS = 174597;
    parameter N_BLOCKS = 1200;
    parameter N_PIXELS = 307200;
    reg [23:0] mem_gaussian_id_in [DUPLICATE_GAUSSIANS -1 :0];
    reg [23:0] mem_range [(2 * N_BLOCKS) -1 :0];

    reg [3:0] Gradient_s_axi_arid_reg;
    reg [31:0] Gradient_s_axi_araddr_reg;
    reg [7:0] Gradient_s_axi_arlen_reg;
    reg [2:0] Gradient_s_axi_arsize_reg;
    reg [1:0] Gradient_s_axi_arburst_reg;
    reg Gradient_s_axi_arvalid_reg;

    reg Gradient_s_axi_rready_reg;
    reg [15:0] read_id;

    wire [23:0] reading_Gradient_id;

    wire ar_handshake;
    wire r_handshake;

    integer file_handle;

    reg first_ar_ready;
    
    
    initial begin
        $readmemh("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_15000_fp16/point_list.hex", mem_gaussian_id_in);
        $readmemh("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_15000_fp16/ranges.hex", mem_range);
    end



    initial begin
        $fsdbDumpfile("../output_axi4_test/axi4_test_dump.fsdb");
        $fsdbDumpvars(0, tb_Block_RAM_AXI4_test, "+all");
    end
    // Instantiate the DUT (Device Under Test)
    Block_RAM_AXI4_test #() 
    Block_RAM_AXI4_test_inst (
        .clk(clk),
        .rst_n(rst_n),

        .Gradient_rsta_busy(Gradient_rsta_busy),
        .Gradient_rstb_busy(Gradient_rstb_busy),
        
        .s_aresetn(s_aresetn),

        .Gradient_s_axi_awid(Gradient_s_axi_awid),
        .Gradient_s_axi_awaddr(Gradient_s_axi_awaddr),
        .Gradient_s_axi_awlen(Gradient_s_axi_awlen),
        .Gradient_s_axi_awsize(Gradient_s_axi_awsize),
        .Gradient_s_axi_awburst(Gradient_s_axi_awburst),
        .Gradient_s_axi_awvalid(Gradient_s_axi_awvalid),
        .Gradient_s_axi_awready(Gradient_s_axi_awready),

        .Gradient_s_axi_wdata(Gradient_s_axi_wdata),
        .Gradient_s_axi_wstrb(Gradient_s_axi_wstrb),
        .Gradient_s_axi_wlast(Gradient_s_axi_wlast),
        .Gradient_s_axi_wvalid(Gradient_s_axi_wvalid),
        .Gradient_s_axi_wready(Gradient_s_axi_wready),

        .Gradient_s_axi_bid(Gradient_s_axi_bid),
        .Gradient_s_axi_bresp(Gradient_s_axi_bresp),
        .Gradient_s_axi_bvalid(Gradient_s_axi_bvalid),
        .Gradient_s_axi_bready(Gradient_s_axi_bready),

        .Gradient_s_axi_arid(Gradient_s_axi_arid),
        .Gradient_s_axi_araddr(Gradient_s_axi_araddr),
        .Gradient_s_axi_arlen(Gradient_s_axi_arlen),
        .Gradient_s_axi_arsize(Gradient_s_axi_arsize),
        .Gradient_s_axi_arburst(Gradient_s_axi_arburst),
        .Gradient_s_axi_arvalid(Gradient_s_axi_arvalid),
        .Gradient_s_axi_arready(Gradient_s_axi_arready),

        .Gradient_s_axi_rid(Gradient_s_axi_rid),
        .Gradient_s_axi_rdata(Gradient_s_axi_rdata),
        .Gradient_s_axi_rresp(Gradient_s_axi_rresp),
        .Gradient_s_axi_rlast(Gradient_s_axi_rlast),
        .Gradient_s_axi_rvalid(Gradient_s_axi_rvalid),
        .Gradient_s_axi_rready(Gradient_s_axi_rready)
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

        file_handle = $fopen("../output_backward/time_record.txt", "w");

        clk <= 1'b0;
        rst_n <= 1'b0;
        s_aresetn <= 1'b1;

        Gradient_s_axi_arid_reg <= 4'h0;
        Gradient_s_axi_araddr_reg <= 16'h0;
        Gradient_s_axi_arlen_reg <= 8'h0;
        Gradient_s_axi_arsize_reg <= 3'h0;
        Gradient_s_axi_arburst_reg <= 2'h0;
        Gradient_s_axi_arvalid_reg <= 1'b0;

        Gradient_s_axi_rready_reg <= 1'b0;

        testbench_start <= 1'b0;
        read_id <= 16'd0;

        @ (posedge clk);
        rst_n <= 1'b1;
        testbench_start <= 1'b1;
    end


    always @(posedge clk) begin
        if (!rst_n) begin
            Gradient_s_axi_arid_reg <= 4'h0;
            Gradient_s_axi_araddr_reg <= 16'h0;
            Gradient_s_axi_arlen_reg <= 8'h0;
            Gradient_s_axi_arsize_reg <= 3'h0;
            Gradient_s_axi_arburst_reg <= 2'h0;
            Gradient_s_axi_arvalid_reg <= 1'b0;
            Gradient_s_axi_rready_reg <= 1'b0;
            read_id <= 16'd0;
        end

        else begin

            if (testbench_start) begin
                
                Gradient_s_axi_araddr_reg <= mem_gaussian_id_in[read_id];

                Gradient_s_axi_arid_reg <= 'd0;
                Gradient_s_axi_arlen_reg <= 'd0;
                Gradient_s_axi_arsize_reg <= 3'b101;
                Gradient_s_axi_arburst_reg <= 2'h0;
                read_id <= 'd0;
                
                Gradient_s_axi_arvalid_reg <= 1'b1;
                
                Gradient_s_axi_rready_reg <= 1'b1;

                if (read_id < mem_range[1] - 1) begin
                    if (ar_handshake) begin
                        
                        read_id <= read_id + 1'b1;                        
                        Gradient_s_axi_arid_reg <= read_id + 1'b1;
                        Gradient_s_axi_araddr_reg <= mem_gaussian_id_in[read_id + 1'b1];
                    end

                    
                end


                else begin
                    Gradient_s_axi_arid_reg <= 4'h0;
                    Gradient_s_axi_araddr_reg <= 16'h0;
                    Gradient_s_axi_arlen_reg <= 8'h0;
                    Gradient_s_axi_arsize_reg <= 3'h0;
                    Gradient_s_axi_arburst_reg <= 2'h0;
                    Gradient_s_axi_arvalid_reg <= 1'b0;

                    Gradient_s_axi_rready_reg <= 1'b0;
                    
                    @(posedge clk);
                    @(posedge clk);
                    @(posedge clk);


                    $finish;
                end


            end
        end

    end


    // aw channel
    assign Gradient_s_axi_awid = 'h0;
    assign Gradient_s_axi_awaddr = 'h0;
    assign Gradient_s_axi_awlen = 'h0;
    assign Gradient_s_axi_awsize = 'h0;
    assign Gradient_s_axi_awburst = 'h0;
    assign Gradient_s_axi_awvalid = 'b0;

    // w channel
    assign Gradient_s_axi_wdata = 'h0;
    assign Gradient_s_axi_wstrb = 'h0;
    assign Gradient_s_axi_wlast = 'b0;
    assign Gradient_s_axi_wvalid = 'b0;

    // b channel
    assign Gradient_s_axi_bready = 1'b0;

    // ar channel
    assign Gradient_s_axi_arid = Gradient_s_axi_arid_reg;
    assign Gradient_s_axi_araddr = Gradient_s_axi_araddr_reg;
    assign Gradient_s_axi_arlen = Gradient_s_axi_arlen_reg;
    assign Gradient_s_axi_arsize = Gradient_s_axi_arsize_reg;
    assign Gradient_s_axi_arburst = Gradient_s_axi_arburst_reg;
    assign Gradient_s_axi_arvalid = Gradient_s_axi_arvalid_reg;

    // r channel
    assign Gradient_s_axi_rready = Gradient_s_axi_rready_reg;
    
    assign reading_Gradient_id = mem_gaussian_id_in[read_id];
    
    assign ar_handshake = Gradient_s_axi_arvalid && Gradient_s_axi_arready;
    assign r_handshake = Gradient_s_axi_rvalid && Gradient_s_axi_rready;
    

endmodule