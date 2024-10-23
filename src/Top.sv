module Top (
    input  logic        clk,
    input  logic        rst_n
);

    // Top memory (dummy initialization for testing)
    logic [31:0] top_memory[255:0];

    // Block memories (dummy initialization for testing)
    logic [31:0] block_memory[2:0][255:0];

    // Pixel group memories (dummy initialization for testing)
    logic [31:0] pixel_memory[2:0][2:0][255:0];

    // Wires between the top controller and block controllers
    logic [2:0] req_block, ready_block;
    logic [31:0] data_top_out;
    logic [7:0] addr_top_mem;

    // Wires between block controllers and pixel group controllers
    logic [2:0] req_pixel_group[2:0], ready_pixel_group[2:0];
    logic [31:0] data_block_out[2:0];

    // Instantiate the top controller
    top_controller u_top_controller (
        .clk(clk),
        .rst_n(rst_n),
        .data_out(data_top_out),
        .req_block(req_block),
        .ready_block(ready_block),
        .addr_top_mem(addr_top_mem),
        .top_memory(top_memory)
    );

    // Instantiate 3 block controllers
    generate
        genvar i;
        for (i = 0; i < 3; i++) begin : block_ctrls
            block_controller u_block_controller (
                .clk(clk),
                .rst_n(rst_n),
                .req_top(req_block[i]),
                .ready_top(ready_block[i]),
                .data_out(data_block_out[i]),
                .req_pixel_group(req_pixel_group[i]),
                .ready_pixel_group(ready_pixel_group[i]),
                .addr_block_mem(addr_block_mem),
                .block_memory(block_memory[i])
            );

            // Instantiate 3 pixel group controllers per block controller
            for (genvar j = 0; j < 3; j++) begin : pixel_groups
                pixel_group_controller u_pixel_group_controller (
                    .clk(clk),
                    .rst_n(rst_n),
                    .req_block(req_pixel_group[i][j]),
                    .ready_block(ready_pixel_group[i][j]),
                    .addr_pixel_mem(addr_pixel_mem),
                    .pixel_memory(pixel_memory[i][j])
                );
            end
        end
    endgenerate

endmodule
