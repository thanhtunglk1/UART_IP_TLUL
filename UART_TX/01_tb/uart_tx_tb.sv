module tb_uart_tx;

    // Parameters
    localparam CLK_PERIOD = 20; // 50 MHz clock (20 ns period)
    localparam BAUD_RATE = 9600; // Baud rate for simulation
    localparam OV_SAMP = 16; // Oversampling factor
    localparam BAUD_PERIOD = 1_000_000_000 / BAUD_RATE; // Baud period in ns (104166.67 ns)
    localparam SAMPLE_PERIOD = BAUD_PERIOD / OV_SAMP; // Sample period in ns (~6510.42 ns)

    // DUT signals
    logic       i_clk;
    logic       i_baud;
    logic       i_rst_n;
    logic       i_tx_en;
    logic       i_fifo_tx_emty;
    logic [7:0] i_data;
    logic [2:0] i_parity_sel;
    logic       i_stop_sel;
    logic [1:0] i_width_sel;
    logic       o_tx;
    logic       o_tx_done;

    // Testbench signals
    logic [7:0] expected_data;
    logic       expected_parity;
    logic       error_flag;
    integer     bit_count;
    integer     test_count;
    integer     pass_count;
    integer     fail_count;

    // Instantiate DUT
    uart_tx #(
        .OV_SAMP(OV_SAMP)
    ) uut (
        .i_clk(i_clk),
        .i_baud(i_baud),
        .i_rst_n(i_rst_n),
        .i_tx_en(i_tx_en),
        .i_fifo_tx_emty(i_fifo_tx_emty),
        .i_data(i_data),
        .i_parity_sel(i_parity_sel),
        .i_stop_sel(i_stop_sel),
        .i_width_sel(i_width_sel),
        .o_tx(o_tx),
        .o_tx_done(o_tx_done)
    );

    // Clock generation
    initial begin
        i_clk = 0;
        forever #(CLK_PERIOD/2) i_clk = ~i_clk; // 10 ns toggle -> 50 MHz
    end

    initial begin 
        $shm_open("waves.shm");
        $shm_probe("ASM");
    end

    // Baud clock generation
    initial begin
        i_baud = 0;
        forever begin
            #(SAMPLE_PERIOD) i_baud = 1;
            #1 i_baud = 0; // Short pulse for baud tick
        end
    end

    // Reset and initialization
    initial begin
        i_rst_n = 0;
        i_tx_en = 0;
        i_fifo_tx_emty = 1;
        i_data = 8'h00;
        i_parity_sel = 3'b000;
        i_stop_sel = 0;
        i_width_sel = 2'b11;
        error_flag = 0;
        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        // Apply reset
        #(CLK_PERIOD*5);
        i_rst_n = 1;
        #(CLK_PERIOD*5);

        // Run test cases
        run_test_cases();
        $display("Simulation finished. Total tests: %0d, Passed: %0d, Failed: %0d", test_count, pass_count, fail_count);
        $finish;
    end

    // Task to send data and check UART frame
    task send_and_check(
        input [7:0] data,
        input [2:0] parity_sel,
        input       stop_sel,
        input [1:0] width_sel
    );
        integer bit_width;
        logic parity_bit;
        logic [7:0] shift_data;
        string test_name;

        begin
            // Set test configuration
            i_data = data;
            i_parity_sel = parity_sel;
            i_stop_sel = stop_sel;
            i_width_sel = width_sel;
            i_tx_en = 1;
            i_fifo_tx_emty = 0;
            error_flag = 0;
            test_count++;

            // Determine bit width
            case (width_sel)
                2'b00: bit_width = 5;
                2'b01: bit_width = 6;
                2'b10: bit_width = 7;
                2'b11: bit_width = 8;
                default: bit_width = 8;
            endcase

            // Prepare test name for reporting
            test_name = $sformatf("Data=0x%0h, Width=%0d, Parity=%0s, Stop=%0d",
                                  data,
                                  bit_width,
                                  (parity_sel == 3'b000) ? "None" :
                                  (parity_sel == 3'b100) ? "Even" :
                                  (parity_sel == 3'b101) ? "Odd" :
                                  (parity_sel == 3'b110) ? "Stick0" : "Stick1",
                                  stop_sel ? 2 : 1);

            $display("\n[INFO] Starting test %0d: %s", test_count, test_name);

            // Calculate expected parity
            shift_data = data;
            parity_bit = 0;
            if (parity_sel[2]) begin // Parity enabled
                if (parity_sel[1]) begin // Stick parity
                    parity_bit = parity_sel[0];
                end else begin // Even or Odd parity
                    for (int i = 0; i < bit_width; i++) begin
                        parity_bit = parity_bit ^ shift_data[0];
                        shift_data = shift_data >> 1;
                    end
                    if (parity_sel[0]) // Odd parity
                        parity_bit = ~parity_bit;
                end
            end

            // Wait for transmission to start
            @(negedge o_tx); // Detect start bit
            if (o_tx !== 0) begin
                $display("[ERROR] Test %0d: Expected start bit (0), got %b", test_count, o_tx);
                error_flag = 1;
            end
            #(BAUD_PERIOD);

            // Check data bits
            shift_data = data;
            for (int i = 0; i < bit_width; i++) begin
                if (o_tx !== shift_data[0]) begin
                    $display("[ERROR] Test %0d: Data bit %0d expected %b, got %b", test_count, i, shift_data[0], o_tx);
                    error_flag = 1;
                end
                shift_data = shift_data >> 1;
                #(BAUD_PERIOD);
            end

            // Check parity bit (if enabled)
            if (parity_sel[2]) begin
                if (o_tx !== parity_bit) begin
                    $display("[ERROR] Test %0d: Parity bit expected %b, got %b", test_count, parity_bit, o_tx);
                    error_flag = 1;
                end
                #(BAUD_PERIOD);
            end

            // Check stop bit(s)
            if (o_tx !== 1) begin
                $display("[ERROR] Test %0d: Stop bit 1 expected 1, got %b", test_count, o_tx);
                error_flag = 1;
            end
            #(BAUD_PERIOD);

            if (stop_sel) begin
                if (o_tx !== 1) begin
                    $display("[ERROR] Test %0d: Stop bit 2 expected 1, got %b", test_count, o_tx);
                    error_flag = 1;
                end
                #(BAUD_PERIOD);
            end

            // Check tx_done signal
            @(posedge o_tx_done);
            if (o_tx !== 1) begin
                $display("[ERROR] Test %0d: Expected idle state (1) after tx_done, got %b", test_count, o_tx);
                error_flag = 1;
            end

            // Report result
            if (error_flag) begin
                $display("[FAIL] Test %0d: %s", test_count, test_name);
                fail_count++;
            end else begin
                $display("[PASS] Test %0d: %s", test_count, test_name);
                pass_count++;
            end

            // Reset inputs
            i_tx_en = 0;
            i_fifo_tx_emty = 1;
            #(BAUD_PERIOD*2);
        end
    endtask

    // Task to run all test cases
    task run_test_cases;
        begin
            // Test case 1: 8-bit, no parity, 1 stop bit
            send_and_check(8'hA5, 3'b000, 0, 2'b11);

            // Test case 2: 8-bit, even parity, 1 stop bit
            send_and_check(8'hA5, 3'b100, 0, 2'b11);

            // Test case 3: 8-bit, odd parity, 1 stop bit
            send_and_check(8'hA5, 3'b101, 0, 2'b11);

            // Test case 4: 8-bit, stick parity 0, 1 stop bit
            send_and_check(8'hA5, 3'b110, 0, 2'b11);

            // Test case 5: 8-bit, stick parity 1, 1 stop bit
            send_and_check(8'hA5, 3'b111, 0, 2'b11);

            // Test case 6: 8-bit, no parity, 2 stop bits
            send_and_check(8'hA5, 3'b000, 1, 2'b11);

            // Test case 7: 7-bit, no parity, 1 stop bit
            send_and_check(8'h7F, 3'b000, 0, 2'b10);

            // Test case 8: 7-bit, even parity, 1 stop bit
            send_and_check(8'h7F, 3'b100, 0, 2'b10);

            // Test case 9: 6-bit, no parity, 1 stop bit
            send_and_check(8'h3F, 3'b000, 0, 2'b01);

            // Test case 10: 6-bit, odd parity, 1 stop bit
            send_and_check(8'h3F, 3'b101, 0, 2'b01);

            // Test case 11: 5-bit, no parity, 1 stop bit
            send_and_check(8'h1F, 3'b000, 0, 2'b00);

            // Test case 12: 5-bit, even parity, 2 stop bits
            send_and_check(8'h1F, 3'b100, 1, 2'b00);

            // Test case 13: 8-bit, no parity, 1 stop bit, different data
            send_and_check(8'h5A, 3'b000, 0, 2'b11);

            // Test case 14: Edge case - all zeros
            send_and_check(8'h00, 3'b000, 0, 2'b11);

            // Test case 15: Edge case - all ones
            send_and_check(8'hFF, 3'b000, 0, 2'b11);
        end
    endtask

endmodule