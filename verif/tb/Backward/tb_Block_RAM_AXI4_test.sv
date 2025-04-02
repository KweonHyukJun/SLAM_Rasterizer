
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

    wire [11:0] Pixel_s_axi_awid;
    wire [31:0] Pixel_s_axi_awaddr;
    wire [7:0] Pixel_s_axi_awlen;
    wire [2:0] Pixel_s_axi_awsize;
    wire [1:0] Pixel_s_axi_awburst;
    wire Pixel_s_axi_awvalid;

    wire [159:0] Pixel_s_axi_wdata;
    // wire [255:0] Pixel_s_axi_wdata;
    wire [3:0] Pixel_s_axi_wstrb;
    wire Pixel_s_axi_wlast;
    wire Pixel_s_axi_wvalid;
    
    wire [11:0] Pixel_s_axi_bid;
    wire [1:0] Pixel_s_axi_bresp;
    wire Pixel_s_axi_bready;

    wire [11:0] Pixel_s_axi_arid;
    wire [31:0] Pixel_s_axi_araddr;
    wire [7:0] Pixel_s_axi_arlen;
    wire [2:0] Pixel_s_axi_arsize;
    wire [1:0] Pixel_s_axi_arburst;
    wire Pixel_s_axi_arvalid;

    wire [11:0] Pixel_s_axi_rid;
    wire [159:0] Pixel_s_axi_rdata;
    // wire [255:0] Pixel_s_axi_rdata;
    wire [1:0] Pixel_s_axi_rresp;
    wire Pixel_s_axi_rlast;
    wire Pixel_s_axi_rready;
    

    // output

    // for R/V handshake
    wire Pixel_s_axi_awready;
    wire Pixel_s_axi_wready;
    wire Pixel_s_axi_bvalid;
    wire Pixel_s_axi_arready;
    wire Pixel_s_axi_rvalid;

    wire Pixel_rsta_busy;
    wire Pixel_rstb_busy;


    // internal signal
    reg testbench_start;

    parameter N_GAUSSIANS = 31985;
    parameter DUPLICATE_GAUSSIANS = 174597;
    parameter N_BLOCKS = 1200;
    parameter N_PIXELS = 307200;
    reg [23:0] mem_gaussian_id_in [DUPLICATE_GAUSSIANS -1 :0];
    reg [23:0] mem_range [(2 * N_BLOCKS) -1 :0];

    reg [3:0] Pixel_s_axi_arid_reg;
    reg [31:0] Pixel_s_axi_araddr_reg;
    reg [7:0] Pixel_s_axi_arlen_reg;
    reg [2:0] Pixel_s_axi_arsize_reg;
    reg [1:0] Pixel_s_axi_arburst_reg;
    reg Pixel_s_axi_arvalid_reg;

    reg Pixel_s_axi_rready_reg;
    reg [15:0] read_id;

    wire [23:0] reading_Pixel_id;

    wire ar_handshake;
    wire r_handshake;

    integer file_handle;

    reg first_ar_ready;
    
    
    initial begin
        $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/point_list.hex", mem_gaussian_id_in);
        $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/ranges.hex", mem_range);
    end



    initial begin
        $fsdbDumpfile("../output_shared_submodules/shared_submodules_dump.fsdb");
        $fsdbDumpvars(0, tb_Block_RAM_AXI4_test, "+all");
    end
    // Instantiate the DUT (Device Under Test)
    Block_RAM_AXI4_test #() 
    Block_RAM_AXI4_test_inst (
        .clk(clk),
        .rst_n(rst_n),

        .Pixel_rsta_busy(Pixel_rsta_busy),
        .Pixel_rstb_busy(Pixel_rstb_busy),
        
        .s_aresetn(s_aresetn),

        .Pixel_s_axi_awid(Pixel_s_axi_awid),
        .Pixel_s_axi_awaddr(Pixel_s_axi_awaddr),
        .Pixel_s_axi_awlen(Pixel_s_axi_awlen),
        .Pixel_s_axi_awsize(Pixel_s_axi_awsize),
        .Pixel_s_axi_awburst(Pixel_s_axi_awburst),
        .Pixel_s_axi_awvalid(Pixel_s_axi_awvalid),
        .Pixel_s_axi_awready(Pixel_s_axi_awready),

        .Pixel_s_axi_wdata(Pixel_s_axi_wdata),
        .Pixel_s_axi_wstrb(Pixel_s_axi_wstrb),
        .Pixel_s_axi_wlast(Pixel_s_axi_wlast),
        .Pixel_s_axi_wvalid(Pixel_s_axi_wvalid),
        .Pixel_s_axi_wready(Pixel_s_axi_wready),

        .Pixel_s_axi_bid(Pixel_s_axi_bid),
        .Pixel_s_axi_bresp(Pixel_s_axi_bresp),
        .Pixel_s_axi_bvalid(Pixel_s_axi_bvalid),
        .Pixel_s_axi_bready(Pixel_s_axi_bready),

        .Pixel_s_axi_arid(Pixel_s_axi_arid),
        .Pixel_s_axi_araddr(Pixel_s_axi_araddr),
        .Pixel_s_axi_arlen(Pixel_s_axi_arlen),
        .Pixel_s_axi_arsize(Pixel_s_axi_arsize),
        .Pixel_s_axi_arburst(Pixel_s_axi_arburst),
        .Pixel_s_axi_arvalid(Pixel_s_axi_arvalid),
        .Pixel_s_axi_arready(Pixel_s_axi_arready),

        .Pixel_s_axi_rid(Pixel_s_axi_rid),
        .Pixel_s_axi_rdata(Pixel_s_axi_rdata),
        .Pixel_s_axi_rresp(Pixel_s_axi_rresp),
        .Pixel_s_axi_rlast(Pixel_s_axi_rlast),
        .Pixel_s_axi_rvalid(Pixel_s_axi_rvalid),
        .Pixel_s_axi_rready(Pixel_s_axi_rready)
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

        Pixel_s_axi_arid_reg <= 4'h0;
        Pixel_s_axi_araddr_reg <= 16'h0;
        Pixel_s_axi_arlen_reg <= 8'h0;
        Pixel_s_axi_arsize_reg <= 3'h0;
        Pixel_s_axi_arburst_reg <= 2'h0;
        Pixel_s_axi_arvalid_reg <= 1'b0;

        Pixel_s_axi_rready_reg <= 1'b0;

        testbench_start <= 1'b0;
        read_id <= 16'd0;

        @ (posedge clk);
        rst_n <= 1'b1;
        testbench_start <= 1'b1;
    end


    always @(posedge clk) begin
        if (!rst_n) begin
            Pixel_s_axi_arid_reg <= 4'h0;
            Pixel_s_axi_araddr_reg <= 16'h0;
            Pixel_s_axi_arlen_reg <= 8'h0;
            Pixel_s_axi_arsize_reg <= 3'h0;
            Pixel_s_axi_arburst_reg <= 2'h0;
            Pixel_s_axi_arvalid_reg <= 1'b0;
            Pixel_s_axi_rready_reg <= 1'b0;
            read_id <= 16'd0;
        end

        else begin

            if (testbench_start) begin
                
                Pixel_s_axi_araddr_reg <= mem_gaussian_id_in[read_id];

                Pixel_s_axi_arid_reg <= 'd0;
                Pixel_s_axi_arlen_reg <= 'd0;
                Pixel_s_axi_arsize_reg <= 3'b101;
                Pixel_s_axi_arburst_reg <= 2'h0;
                read_id <= 'd0;
                
                Pixel_s_axi_arvalid_reg <= 1'b1;
                
                Pixel_s_axi_rready_reg <= 1'b1;

                if (read_id < mem_range[1] - 1) begin
                    if (ar_handshake) begin
                        
                        read_id <= read_id + 1'b1;                        
                        Pixel_s_axi_arid_reg <= read_id + 1'b1;
                        Pixel_s_axi_araddr_reg <= mem_gaussian_id_in[read_id + 1'b1];
                    end

                    
                end


                else begin
                    Pixel_s_axi_arid_reg <= 4'h0;
                    Pixel_s_axi_araddr_reg <= 16'h0;
                    Pixel_s_axi_arlen_reg <= 8'h0;
                    Pixel_s_axi_arsize_reg <= 3'h0;
                    Pixel_s_axi_arburst_reg <= 2'h0;
                    Pixel_s_axi_arvalid_reg <= 1'b0;

                    Pixel_s_axi_rready_reg <= 1'b0;
                    @(posedge clk);
                    @(posedge clk);
                    @(posedge clk);


                    $finish;
                end


            end
        end

    end


    // aw channel
    assign Pixel_s_axi_awid = 'h0;
    assign Pixel_s_axi_awaddr = 'h0;
    assign Pixel_s_axi_awlen = 'h0;
    assign Pixel_s_axi_awsize = 'h0;
    assign Pixel_s_axi_awburst = 'h0;
    assign Pixel_s_axi_awvalid = 'b0;

    // w channel
    assign Pixel_s_axi_wdata = 'h0;
    assign Pixel_s_axi_wstrb = 'h0;
    assign Pixel_s_axi_wlast = 'b0;
    assign Pixel_s_axi_wvalid = 'b0;

    // b channel
    assign Pixel_s_axi_bready = 1'b0;

    // ar channel
    assign Pixel_s_axi_arid = Pixel_s_axi_arid_reg;
    assign Pixel_s_axi_araddr = Pixel_s_axi_araddr_reg;
    assign Pixel_s_axi_arlen = Pixel_s_axi_arlen_reg;
    assign Pixel_s_axi_arsize = Pixel_s_axi_arsize_reg;
    assign Pixel_s_axi_arburst = Pixel_s_axi_arburst_reg;
    assign Pixel_s_axi_arvalid = Pixel_s_axi_arvalid_reg;

    // r channel
    assign Pixel_s_axi_rready = Pixel_s_axi_rready_reg;
    
    assign reading_Pixel_id = mem_gaussian_id_in[read_id];
    
    assign ar_handshake = Pixel_s_axi_arvalid && Pixel_s_axi_arready;
    assign r_handshake = Pixel_s_axi_rvalid && Pixel_s_axi_rready;
    

    always @ (posedge clk) begin
        $fwrite(file_handle, "clk cnt %0d\n", clk_cnt);
        $fwrite(file_handle, "ar handshake %0d\n", ar_handshake);
        $fwrite(file_handle, "r handshake %0d\n", r_handshake);
        $fwrite(file_handle, "ar valid %0d\n", Pixel_s_axi_arvalid);
        $fwrite(file_handle, "ar ready %0d\n", Pixel_s_axi_arready);
        $fwrite(file_handle, "r valid %0d\n", Pixel_s_axi_rvalid);
        $fwrite(file_handle, "r ready %0d\n", Pixel_s_axi_rready);

        $fwrite(file_handle, "ar id %0d\n", Pixel_s_axi_arid);
        $fwrite(file_handle, "ar addr %0d\n", Pixel_s_axi_araddr);
        $fwrite(file_handle, "ar len %0d\n", Pixel_s_axi_arlen);
        $fwrite(file_handle, "ar size %0d\n", Pixel_s_axi_arsize);
        $fwrite(file_handle, "ar burst %0d\n", Pixel_s_axi_arburst);
        $fwrite(file_handle, "ar valid %0d\n", Pixel_s_axi_arvalid);
        $fwrite(file_handle, "ar ready %0d\n", Pixel_s_axi_arready);

        $fwrite(file_handle, "r id %0d\n", Pixel_s_axi_rid);
        $fwrite(file_handle, "r data %0d\n", Pixel_s_axi_rdata);
        $fwrite(file_handle, "r resp %0d\n", Pixel_s_axi_rresp);
        $fwrite(file_handle, "r last %0d\n", Pixel_s_axi_rlast);
        $fwrite(file_handle, "r valid %0d\n", Pixel_s_axi_rvalid);
        $fwrite(file_handle, "r ready %0d\n\n\n\n\n\n", Pixel_s_axi_rready);
    end


endmodule