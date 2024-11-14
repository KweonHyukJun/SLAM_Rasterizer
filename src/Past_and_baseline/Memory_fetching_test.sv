module Memory_fetching_test #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BURST_LEN_WIDTH = 8,
    parameter RAM_ADDR_WIDTH = 10,
    parameter RAM_DATA_WIDTH = 512,
    parameter RAM_DEPTH = 1024,
    parameter NUM_REQUESTS = 4 // Number of memory requests
) (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [NUM_REQUESTS-1:0][ADDR_WIDTH-1:0] ext_mem_addr, // Array of addresses
    input wire [NUM_REQUESTS-1:0][BURST_LEN_WIDTH-1:0] burst_len, // Array of burst lengths
    input wire [DATA_WIDTH-1:0] data_from_ext_mem,
    output wire [ADDR_WIDTH-1:0] ext_mem_read_addr,
    output wire ext_mem_read_req,
    output wire [DATA_WIDTH-1:0] data_to_ram,
    output wire done
);

    // Internal signals
    wire [ADDR_WIDTH-1:0] mem_ctrl_read_addr;
    wire mem_ctrl_read_req;
    wire [DATA_WIDTH-1:0] mem_ctrl_data_to_ram;
    wire mem_ctrl_done;

    // Instantiate MemoryController
    Memory_fetching_test_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BURST_LEN_WIDTH(BURST_LEN_WIDTH),
        .NUM_REQUESTS(NUM_REQUESTS)
    ) mem_ctrl (
        .clk(clk),
        .rst(rst),
        .start(start),
        .addr(ext_mem_addr),
        .burst_len(burst_len),
        .data_from_memory(data_from_ext_mem),
        .read_req(mem_ctrl_read_req),
        .read_addr(mem_ctrl_read_addr),
        .data_to_memory(mem_ctrl_data_to_ram),
        .done(mem_ctrl_done)
    );

    // Instantiate DP_RAM
    DP_RAM #(
        .N(RAM_DATA_WIDTH),
        .W(RAM_DEPTH)
    ) dp_ram (
        .CLK(clk),
        .AA(mem_ctrl_read_addr[RAM_ADDR_WIDTH-1:0]),
        .D(mem_ctrl_data_to_ram),
        .WEB(~mem_ctrl_read_req), // Active-low Write enable
        .AB(mem_ctrl_read_addr[RAM_ADDR_WIDTH-1:0]),
        .REB(1'b0), // Always enable read
        .Q(),
        .test_mem()
    );

    // Connect external memory interface
    assign ext_mem_read_addr = mem_ctrl_read_addr;
    assign ext_mem_read_req = mem_ctrl_read_req;
    assign data_to_ram = mem_ctrl_data_to_ram;
    assign done = mem_ctrl_done;

endmodule