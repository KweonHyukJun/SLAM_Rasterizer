// Include necessary type definitions
`include "axi/typedef.svh"
`include "axi/assign.svh"


`define MAX_CLOCK_COUNT 1000 // 천만

module tb_AXI_MUX_check;

  integer max_clock_count = `MAX_CLOCK_COUNT;

  // Parameters
  localparam AXI_ID_WIDTH     = 4;
  localparam AXI_ADDR_WIDTH   = 32;
  localparam AXI_DATA_WIDTH   = 32;
  localparam AXI_USER_WIDTH   = 1;
  localparam AXI_STRB_WIDTH   = AXI_DATA_WIDTH/8;
  localparam NO_SLV_PORTS     = 4;  // Number of slave ports

  // Clock and reset
  logic clk;
  logic rst_n;

  // Type definitions using AXI macros
  typedef logic [AXI_ID_WIDTH-1:0]     id_t;
  typedef logic [AXI_ADDR_WIDTH-1:0]   addr_t;
  typedef logic [AXI_DATA_WIDTH-1:0]   data_t;
  typedef logic [AXI_STRB_WIDTH-1:0]   strb_t;
  typedef logic [AXI_USER_WIDTH-1:0]   user_t;

    // Write Address Channel (AW)
    typedef struct packed {
        id_t              id;      // Transaction ID
        addr_t            addr;    // Address
        axi_pkg::len_t    len;     // Burst length (0 = 1 beat, 1 = 2 beats, etc.)
        axi_pkg::size_t   size;    // Size of each beat (2^size bytes)
        axi_pkg::burst_t  burst;   // Burst type (FIXED, INCR, WRAP)
        logic             lock;    // Lock type
        axi_pkg::cache_t  cache;   // Memory type
        axi_pkg::prot_t   prot;    // Protection type
        axi_pkg::qos_t    qos;     // Quality of Service
        axi_pkg::region_t region;  // Region identifier
        axi_pkg::atop_t   atop;    // Atomic operation
        user_t            user;    // User-defined data
    } aw_chan_t;



  // Define AXI channel and request/response types
  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t)
  `AXI_TYPEDEF_REQ_T(req_t, aw_chan_t, w_chan_t, ar_chan_t)
  `AXI_TYPEDEF_RESP_T(resp_t, b_chan_t, r_chan_t)



  // Signals
  req_t  [NO_SLV_PORTS-1:0] slv_reqs;
  resp_t [NO_SLV_PORTS-1:0] slv_resps;
  req_t                     mst_req;
  resp_t                    mst_resp;

    initial begin
        $fsdbDumpfile("../output_axi_mux/axi_mux_dump.fsdb");
        $fsdbDumpvars(0, tb_AXI_MUX_check, "+all");
    end


  // Clock generation
    always begin
        #0.5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == max_clock_count) $finish;
    end


  // Example AXI4 BREAM
  Test_AXI4_BRAM #()
  Test_AXI4_BRAM_inst
  (
    .clk(clk),
    .aresetn (rst_n),

  );




  // DUT instantiation
  axi_mux #(
    .SlvAxiIDWidth ( AXI_ID_WIDTH     ),
    .NoSlvPorts    ( NO_SLV_PORTS     ),
    .MaxWTrans     ( 8                ),
    .FallThrough   ( 1'b0             ),
    .SpillAw       ( 1'b1             ),
    .SpillW        ( 1'b0             ),
    .SpillB        ( 1'b0             ),
    .SpillAr       ( 1'b1             ),
    .SpillR        ( 1'b0             )
  ) i_axi_mux (
    .clk_i       ( clk       ),
    .rst_ni      ( rst_n     ),
    .test_i      ( 1'b0      ),
    .slv_reqs_i  ( slv_reqs  ),
    .slv_resps_o ( slv_resps ),
    .mst_req_o   ( mst_req   ),
    .mst_resp_i  ( mst_resp  )
  );

  // Test stimulus
  initial begin
    clk <= 1'b0;
    rst_n <= 1'b0;

    @(posedge clk);
    rst_n <= 1'b1;



    // Initialize
    for (int i = 0; i < NO_SLV_PORTS; i++) begin
        slv_reqs[i] = '0;
    end
    mst_resp = '0;

    @(posedge clk);
    // Test Case 1: Basic Write
    slv_reqs[0].aw.id    = 'h1;                    // ID within ID_WIDTH
    slv_reqs[0].aw.addr  = 'h1000;                 // Address within ADDR_WIDTH
    slv_reqs[0].aw_valid = 1'b1;
    slv_reqs[0].w.data   = 'hDEAD_BEEF;           // Data within DATA_WIDTH
    slv_reqs[0].w.strb   = {(AXI_DATA_WIDTH/8){1'b1}}; // All bytes valid
    slv_reqs[0].w.last   = 1'b1;
    slv_reqs[0].w_valid  = 1'b1;

    // Wait for handshake
    @(posedge clk);
    while (!slv_resps[0].aw_ready) @(posedge clk);
    slv_reqs[0].aw_valid = 1'b0;

    // Test Case 2: Read transaction from slave port 0
    slv_reqs[0].ar.id    = 4'h1;
    slv_reqs[0].ar.addr  = 32'h1000_0000;
    slv_reqs[0].ar_valid = 1'b1;

    // Wait for read response
    @(posedge clk);
    while (!slv_resps[0].ar_ready) @(posedge clk);
    slv_reqs[0].ar_valid = 1'b0;

    // Add more test cases as needed...

    // End simulation
    #1000;
    $finish;
  end

  // Monitor
  initial begin
    forever @(posedge clk) begin
      if (mst_req.aw_valid && mst_resp.aw_ready) begin
        $display("Time=%0t: Write request - Addr=0x%h, ID=%h", 
                 $time, mst_req.aw.addr, mst_req.aw.id);
      end
    end
  end

endmodule

