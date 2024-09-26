module skip_and_alpha_test(
    clk,
    rst,
    valid_wr_i,
    data_Y_i,
    valid_rd_i,
    data_Y_o,
    valid_Y_o
);
localparam Tree_Width = 32;
localparam Tree_Depth = 32;
localparam Tree_Bitwidth_Y = 16;

input               clk;
input               rst;
input               valid_wr_i;
input [Tree_Depth*Tree_Bitwidth_Y-1:0] data_Y_i;
input               valid_rd_i;
output [Tree_Depth*Tree_Bitwidth_Y-1:0] data_Y_o;
output              valid_Y_o;

reg [$clog2(Tree_Depth)-1:0] addr_wr_i;
reg [$clog2(Tree_Depth)-1:0] addr_rd_i;

always @(posedge clk) begin
    if (!rst) begin
        addr_wr_i <= 0;
        addr_rd_i <= 0;
    end
    else begin
        if (valid_wr_i) addr_wr_i <= addr_wr_i + 1;
        if (valid_rd_i) addr_rd_i <= addr_rd_i + 1;
    end
end

skip_and_alpha #(
    .Tree_Width(Tree_Width),
    .Tree_Depth(Tree_Depth),
    .Tree_Bitwidth_Y(Tree_Bitwidth_Y)
) s_and_a (
    .clk(clk),
    .rst(rst),
    .data_Y_i(data_Y_i),
    .valid_wr_i(valid_wr_i),
    .addr_wr_i(addr_wr_i),
    .valid_rd_i(valid_rd_i),
    .addr_rd_i(addr_rd_i),
    .data_Y_o(data_Y_o),
    .valid_Y_o(valid_Y_o)
);
endmodule