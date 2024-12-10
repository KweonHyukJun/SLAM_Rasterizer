module BF16_PE_tb;

    reg clk, rstn;
    reg [16*4-1:0]        din_A;
    reg [16*4-1:0]        din_B;
    wire [16-1:0]      dout;
    wire [3:0]          overflow;

    parameter N_TEST = 2500;
    reg [15:0] mem_din_A [4*N_TEST-1:0];
    reg [15:0] mem_din_B [4*N_TEST-1:0];
    reg [15:0] mem_dout [N_TEST-1:0];

    reg clk, rstn;
    reg [15:0] inst_a;
    reg [15:0] inst_b;
    reg [15:0] inst_c;
    reg [15:0] inst_d;
    reg [15:0] inst_e;
    reg [15:0] inst_f;
    reg [15:0] inst_g;
    reg [15:0] inst_h;
    reg [2:0] inst_rnd;
    wire [15:0] z_inst;
    wire [7:0] status_inst;

    

    initial begin
        $readmemh("/home/nam3918/Practice/verification/hex/din_A.hex", mem_din_A);
        $readmemh("/home/nam3918/Practice/verification/hex/din_B.hex", mem_din_B);
        $readmemh("/home/nam3918/Practice/verification/hex/dout.hex", mem_dout);
    end

    BF16_PE BF16_PE(.clk(clk), .rstn(rstn), .din_A(din_A), .din_B(din_B), .overflow(overflow), .dout(dout));

    DW_fp_dp4 #(7, 8, 0, 0) U1 (
			.a(inst_a),
			.b(inst_b),
			.c(inst_c),
			.d(inst_d),
			.e(inst_e),
			.f(inst_f),
			.g(inst_g),
			.h(inst_h),
			.rnd(inst_rnd),
			.z(z_inst),
			.status(status_inst) );

    initial begin
        rstn = 1;
        clk = 0;
        inst_rnd = 3'b000;
    end

    initial begin
        forever begin
            #10 clk = !clk;
        end
    end


    integer counter = 0;
    always @(posedge clk) begin
        if (counter < N_TEST) begin
            din_A = {mem_din_A[4*counter+3], mem_din_A[4*counter+2], mem_din_A[4*counter+1], mem_din_A[4*counter]};
            din_B = {mem_din_B[4*counter+3], mem_din_B[4*counter+2], mem_din_B[4*counter+1], mem_din_B[4*counter]};
            inst_a = mem_din_A[4*counter];
            inst_b = mem_din_B[4*counter];
            inst_c = mem_din_A[4*counter+1];
            inst_d = mem_din_B[4*counter+1];
            inst_e = mem_din_A[4*counter+2];
            inst_f = mem_din_B[4*counter+2];
            inst_g = mem_din_A[4*counter+3];
            inst_h = mem_din_B[4*counter+3];
            #0.05;
            if(dout != z_inst) begin
                $display("#######################################################");
                $display("Error: dout is incorrect at counter %d", counter);
                $display("dout = %d, ref_dout = %d", dout, z_inst);
                $display("#######################################################");
            end
            #0.05;
            counter = counter + 1;
        end
        else begin
            $display("#######################################################");
            $display("Simulation is done without error.num of test: %d", N_TEST);
            $display("#######################################################");
            $finish;
        end
    end


endmodule