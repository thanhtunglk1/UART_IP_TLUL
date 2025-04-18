module tb_negedge_detect;

    // Inputs
    logic i_clk;
    logic i_rst_n;
    logic i_rx_serial;
    logic i_rx_en;

    // Outputs
    logic o_rx_in;
    logic o_start_signal;

    // Instantiate DUT
    negedge_detect dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_rx_serial(i_rx_serial),
        .i_rx_en(i_rx_en),
        .o_rx_in(o_rx_in),
        .o_start_signal(o_start_signal)
    );

    // Clock generation
    initial i_clk = 0;
    always #5 i_clk = ~i_clk;

    // Variables for checking
    int pass = 0;
    int fail = 0;
    logic [2:0] state;

    initial begin 
        $shm_open("waves.shm");
        $shm_probe("ASM");
    end

    initial begin
        $display("--------------------[TEST] Simulation Started--------------------");

        // Initial values
        i_rst_n     = 0;
        i_rx_serial = 1;
        i_rx_en     = 0;

        #10;
        i_rst_n = 1;
        i_rx_en = 1;

        // Step 1: ổn định đầu vào ở mức cao
        #20;

        // Step 2: tạo cạnh xuống
        @(posedge i_clk);
        #1
        i_rx_serial = 0; // Cạnh xuống

        // Step 3: chờ 3 chu kỳ để kiểm tra o_start_signal
        @(posedge i_clk);
        @(posedge i_clk);
        //@(posedge i_clk);
        #1
        if (o_start_signal === 1) begin
            $display("[PASS] Detected falling edge correctly.");
            pass++;
        end else begin
            $display("[FAIL] Failed to detect falling edge.");
            fail++;
        end

        // Step 4: kiểm tra rằng o_start_signal chỉ xung 1 chu kỳ
        @(posedge i_clk);
        #1
        if (o_start_signal === 0) begin
            $display("[PASS] o_start_signal lasted only one cycle.");
            pass++;
        end else begin
            $display("[FAIL] o_start_signal not cleared after one cycle.");
            fail++;
        end

        // Step 5: Tắt i_rx_en và thử cạnh xuống → không nên có o_start_signal
        i_rx_en = 0;
        i_rx_serial = 1;
        @(posedge i_clk);
        #1
        i_rx_serial = 0; // Cạnh xuống nhưng rx_en = 0

        @(posedge i_clk);
        if (o_start_signal === 0) begin
            $display("[PASS] No start signal when rx_en is low.");
            pass++;
        end else begin
            $display("[FAIL] Start signal triggered even when rx_en = 0.");
            fail++;
        end

        // Kết thúc kiểm tra
        $display("===================================");
        $display("Total Pass: %0d", pass);
        $display("Total Fail: %0d", fail);
        $display("===================================");

        if (fail == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");

        $finish;
    end

endmodule
