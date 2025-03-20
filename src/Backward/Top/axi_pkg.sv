package axi_pkg;

    // Parameterized AXI4 Interface for different data widths
    typedef struct packed {
        logic [11:0] awid;
        logic [23:0] awaddr;
        logic [7:0]  awlen;
        logic [2:0]  awsize;
        logic [1:0]  awburst;
        logic        awvalid;
        logic        awready;
    } axi_aw_t;

    typedef struct packed {
        logic [11:0] bid;
        logic [1:0]  bresp;
        logic        bvalid;
        logic        bready;
    } axi_b_t;

    typedef struct packed {
        logic [11:0] arid;
        logic [23:0] araddr;
        logic [7:0]  arlen;
        logic [2:0]  arsize;
        logic [1:0]  arburst;
        logic        arvalid;
        logic        arready;
    } axi_ar_t;

    // Parameterized AXI4 Data Structs
    typedef struct packed {
        logic [DATA_WIDTH-1:0] wdata;
        logic [(DATA_WIDTH/8)-1:0] wstrb;
        logic         wlast;
        logic         wvalid;
        logic         wready;
    } axi_w_t #(parameter DATA_WIDTH = 32);

    typedef struct packed {
        logic [11:0] rid;
        logic [DATA_WIDTH-1:0] rdata;
        logic [1:0]  rresp;
        logic        rlast;
        logic        rvalid;
        logic        rready;
    } axi_r_t #(parameter DATA_WIDTH = 32);

    // Full AXI4 Interface Struct
    typedef struct packed {
        axi_aw_t aw;
        axi_w_t #(DATA_WIDTH) w;
        axi_b_t  b;
        axi_ar_t ar;
        axi_r_t #(DATA_WIDTH) r;
    } axi_if_t #(parameter DATA_WIDTH = 32);

endpackage
