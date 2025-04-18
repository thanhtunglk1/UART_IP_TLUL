module overrun_check_tb;

    logic i_clk;
    logic i_rst_n;
    logic i_rx_done;
    logic i_rx_fifo_full;
    logic o_overrun_flag;

    // Instantiate the module under test
    overrun_check dut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_rx_done(i_rx_done),
        .i_rx_fifo_full(i_rx_fifo_full),
        .o_overrun_flag(o_overrun_flag)
    );

    initial begin 
        $shm_open("waves.shm");
        $shm_probe("ASM");
    end

    // Clock generation: 10ns period
    always #5 i_clk = ~i_clk;

    // Task to print result
    task check_result(input string testname, input logic expected);
        if (o_overrun_flag === expected)
            $display("PASS: %s , o_overrun_flag = %b", testname, o_overrun_flag);
        else
            $display("FAIL: %s , o_overrun_flag = %b (expected %b)", testname, o_overrun_flag, expected);
    endtask

    initial begin
        // Init signals
        i_clk = 0;
        i_rst_n = 0;
        i_rx_done = 0;
        i_rx_fifo_full = 0;

        // Reset
        #10;
        i_rst_n = 1;
        #10;

        // Test 1: Normal operation, no RX done, no FIFO full => No overrun
        i_rx_done = 0;
        i_rx_fifo_full = 0;
        #10;
        check_result("Test 1: Normal - no RX done, no FIFO full", 0);

        // Test 2: RX done, but FIFO not full => still normal
        i_rx_done = 1;
        i_rx_fifo_full = 0;
        #10;
        check_result("Test 2: RX done, FIFO not full", 0);

        // Test 3: RX done AND FIFO full => overrun
        i_rx_done = 1;
        i_rx_fifo_full = 1;
        #10;
        check_result("Test 3: RX done AND FIFO full", 1);

        // Test 4: FIFO still full => still overrun
        i_rx_done = 0;
        i_rx_fifo_full = 1;
        #10;
        check_result("Test 4: FIFO still full", 1);

        // Test 5: FIFO no longer full => back to normal
        i_rx_fifo_full = 0;
        #10;
        check_result("Test 5: FIFO not full anymore", 0);

        // Test 6: Another overrun scenario
        i_rx_done = 1;
        i_rx_fifo_full = 1;
        #10;
        check_result("Test 6: Second overrun", 1);

        $finish;
    end

endmodule
