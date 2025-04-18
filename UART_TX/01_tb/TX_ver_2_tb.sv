module tb_uart_tx;

    // Parameters
    localparam CLK_PERIOD = 20; // 50 MHz clock
    localparam BAUD_RATE = 115200;
    localparam OV_SAMP = 16;
    localparam BAUD_DIV = 50_000_000 / BAUD_RATE; // clock cycles per baud

    // DUT signals
    logic       i_clk;
    logic       i_baud;
    logic       i_rst_n;
    logic       i_tx_en;
    logic       i_fifo_tx_empty;
    logic [7:0] i_data;
    logic [2:0] i_parity_sel;
    logic       i_stop_sel;
    logic [1:0] i_width_sel;
    logic       o_tx;
    logic       o_tx_done;

    // Instantiate Baud Generator
    baud_gen #(.BAUD_WIDTH(24)) baud (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_brd_value(24'd26),
        .o_baud(i_baud)
    );

    // Instantiate DUT
    uart_tx #(
        .OV_SAMP(OV_SAMP)
    ) uut (
        .i_clk(i_clk),
        .i_baud(i_baud),
        .i_rst_n(i_rst_n),
        .i_tx_en(i_tx_en),
        .i_fifo_tx_emty(i_fifo_tx_empty),
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
        forever #(CLK_PERIOD/2) i_clk = ~i_clk;
    end

    initial begin
        $shm_open("waves.shm");
        $shm_probe("ASM");
    end

    // Helper task: trigger transmission
    task start_transmission(input [7:0] data);
        begin
            i_data = data;
            i_fifo_tx_empty = 0; // FIFO has data
            i_tx_en = 1;
            @(posedge i_clk);
            i_tx_en = 0;
        end
    endtask

    initial begin
        // Initialization
        i_rst_n = 0;
        i_tx_en = 0;
        i_fifo_tx_empty = 1;
        i_data = 8'h00;
        i_parity_sel = 3'b000; // No parity
        i_stop_sel = 0; // 1 stop bit
        i_width_sel = 2'b11; // 8-bit data

        $display("Resetting DUT...");
        #100;
        i_rst_n = 1;
        $display("Reset complete. Begin test...");

        // Wait a few baud clocks before starting
        repeat(4) @(posedge i_baud);

        // Test 1: Transmit 0x55
        $display("TEST 1: Transmit 0x55");
        start_transmission(8'h55);

        // Start bit check
        @(posedge i_baud);
        if (o_tx !== 0) $display("Start bit FAIL: expected 0, got %b", o_tx);
        else $display("Start bit OK");

        // Data bits check
        for (int i = 0; i < 8; i++) begin
            @(posedge i_baud);
            if (o_tx !== i_data[i])
                $display("Data bit %0d FAIL: expected %b, got %b", i, i_data[i], o_tx);
            else
                $display("Data bit %0d OK: %b", i, o_tx);
        end

        // Stop bit check
        @(posedge i_baud);
        if (o_tx !== 1) $display("Stop bit FAIL: expected 1, got %b", o_tx);
        else $display("Stop bit OK");

        wait(o_tx_done);
        $display("TX DONE OK for 0x55");

        // Test 2: Transmit 0xAA
        repeat(3) @(posedge i_baud);
        $display("TEST 2: Transmit 0xAA");
        start_transmission(8'hAA);

        @(posedge i_baud);
        if (o_tx !== 0) $display("Start bit FAIL: expected 0, got %b", o_tx);
        else $display("Start bit OK");

        for (int i = 0; i < 8; i++) begin
            @(posedge i_baud);
            if (o_tx !== i_data[i])
                $display("Data bit %0d FAIL: expected %b, got %b", i, i_data[i], o_tx);
            else
                $display("Data bit %0d OK: %b", i, o_tx);
        end

        @(posedge i_baud);
        if (o_tx !== 1) $display("Stop bit FAIL: expected 1, got %b", o_tx);
        else $display("Stop bit OK");

        wait(o_tx_done);
        $display("TX DONE OK for 0xAA");

        // Done
        #1000;
        $display("All tests completed.");
        $finish;
    end

endmodule
