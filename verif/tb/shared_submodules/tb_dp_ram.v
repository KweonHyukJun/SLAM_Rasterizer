module tb_dp_ram 
#(
    parameter N = 207,
    parameter W = 5
)();


    localparam M = $clog2(W);

    //input
    reg [M-1:0] AA;
    reg [N-1:0] D;
    reg WEB;
    reg [M-1:0] AB;
    reg REB;
    reg clk;

    //output
    wire [N-1:0] Q;
    wire [N-1:0] test_mem [0:W-1];

    initial begin
        $fsdbDumpfile("./output_shared_submodules/shared_submodules_dump.fsdb");
        $fsdbDumpvars(0, tb_dp_ram, "+all");    
    end

    dp_ram #(N, W) u_dp_ram(
        .clk(clk),
        .AA(AA),
        .D(D),
        .WEB(WEB),
        .AB(AB),
        .REB(REB),
        .Q(Q),
        .test_mem(test_mem)
    );


    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize inputs
        AA = 'h0;
        D = 'h0; 
        WEB = 1'b1;
        AB = 'h0;
        REB = 1'b1;

        @(posedge clk);

        // Test write operation
        WEB = 1'b0; // Enable write
        AA = 'h1;
        D = 'hABCD; // Test data pattern
        @(posedge clk);
        WEB = 1'b1; // Disable write

        // Test read operation 
        REB = 1'b0; // Enable read
        AB = 'h1; // Read from same address
        D = 'h0;
        // @(posedge clk);
        
        // // Verify read data matches written data
        // if (Q !== 'hABCD) begin
        //     $display("ERROR: Read data mismatch. Expected: %h, Got: %h", 'hABCD, Q);
        // end else begin
        //     $display("PASS: Read data matches written data");
        // end

        // // Test read/write contention
        // WEB = 1'b0;
        // REB = 1'b0;
        // AA = 'h2;
        // AB = 'h2;
        // D = 'h1234;
        @(posedge clk);
        REB = 1'b1;
        // Test writing to multiple addresses
        for (int i=0; i<5; i++) begin
            WEB = 1'b0;
            AA = i;
            D = i + 'h1000;
            @(posedge clk);
        end

        // Read back and verify multiple addresses
        for (int i=0; i<5; i++) begin
            WEB = 1'b1;
            REB = 1'b0;
            AB = i;
            @(posedge clk);
            if (Q !== (i + 'h1000)) begin
                $display("ERROR: Read data mismatch at addr %0d. Expected: %h, Got: %h", 
                    i, i+'h1000, Q);
            end
        end

        #100;
        $display("Testbench completed");
        $finish;
    end




    endmodule