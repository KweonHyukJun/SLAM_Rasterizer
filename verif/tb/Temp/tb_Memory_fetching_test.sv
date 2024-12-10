module tb_Memory_fetching_test;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 10;

    // Signals
    reg clk;
    reg rst_n;

    reg W, H;




    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_Memory_fetching_test, "+all");
    end
    // Instantiate the DUT (Device Under Test)
    Memory_fetching_test #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    dut (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .data_out(data_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin

    end



    // Test sequence
    initial begin
        // Initialize address
        addr = 0;

        // Wait for reset deassertion
        @(negedge rst_n);
        @(posedge rst_n);



        // Apply test vectors
        repeat (10) begin
            @(posedge clk);
            addr = addr + 1;
        end

        // Finish simulation
        #100 $finish;
    end

endmodule