module dp_ram
    #(
        parameter N = 176, // 저장 Bit 수
        parameter W = 64 // Data 개수
    )
    (
    clk,
    rst_n,
    AA,
    D,
    WEB,
    AB,
    REB,
    Q
    // ,test_mem
    );
    // synopsys template

localparam M = $clog2(W);
    // Input-Output declarations
    input [M-1:0] AA;                // Address write bus
    input [N-1:0] D;                 // Date input bus
    input         WEB;               // Active-low Write enable
    input [M-1:0] AB;                // Address read bus
    input         REB;               // Active-low Read enable
    input         clk;
    input         rst_n;
    output [N-1:0] Q;                 // Data output bus
    ////////////for test////////
    // output [N-1:0] test_mem [0:W-1];
    ////////////////////////////
    reg [M-1:0] AA_captured;
    reg [N-1:0] D_captured;
    reg WEB_captured;
    reg [M-1:0] AB_captured;
    integer i;
    reg [N-1:0] mem [0:W-1];

    always @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < W; i++) begin
                mem[i] <= '0;
            end
        end

        // if ((AA==AB)&((!WEB)&(!REB))) begin
        //     // You can add displays for debugging purposes during testing
        //     $display("ERR : READ/WRITE CONTENTION!!!");
        // end

        AA_captured <= AA;
        D_captured <= D;
        WEB_captured <= WEB;
        if (!WEB_captured) begin
            for (i=0; i<N; i=i+1) begin
                mem[AA_captured][i] = D_captured[i];
            end
        end

        if (!REB) begin
            AB_captured <= AB;
        end

        // REB == 1
        else begin
            AB_captured <= 'dx;
        end

    end
    assign Q = mem[AB_captured];
    // assign test_mem = mem;
endmodule