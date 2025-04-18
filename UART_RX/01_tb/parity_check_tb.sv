`timescale 1ns/1ps

module tb_parity_check;

    // Inputs to DUT
    logic        i_clk, i_rst_n;
    logic        i_rx_in;
    logic        i_count_full;
    logic [2:0]  i_parity_sel;
    logic [2:0]  i_p_state;

    // Output from DUT
    logic        o_parity_flag;

    // Test control variables
    int total_tests = 0;
    int passed_tests = 0;
    logic [7:0] data;
    int num_bits;

    // Instantiate DUT
    parity_check uut (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_rx_in(i_rx_in),
        .i_count_full(i_count_full),
        .i_parity_sel(i_parity_sel),
        .i_p_state(i_p_state),
        .o_parity_flag(o_parity_flag)
    );

    initial begin 
        $shm_open("waves.shm");
        $shm_probe("ASM");
    end

    // Clock generation
    always #5 i_clk = ~i_clk;

    task reset();
        i_clk = 0;
        i_rst_n = 0;
        #20;
        i_rst_n = 1;
        #10;
    endtask

    // XOR helper
    function logic calc_xor(input logic [7:0] bits, input int num);
        logic result;
        result = 0;
        for (int i = 0; i < num; i++) begin
            result ^= bits[i];
        end
        return result;
    endfunction

    task send_data(
        input logic [7:0] data_bits,
        input int num_bits,
        input logic parity_bit,
        input [2:0] mode,
        input bit flip_parity,
        input logic exp_flag
    );
        integer i;
        total_tests++;

        i_parity_sel = mode;

        //IDLE
        i_p_state = 3'b000;
        i_rx_in = 1; // idle state
        #10;

        // START
        i_p_state = 3'b001;
        i_rx_in = 0;
        i_count_full = 0;
        #10;

        // RECEIVER
        i_p_state = 3'b010;
        for (i = 0; i < num_bits; i++) begin
            i_rx_in = data_bits[i];
            i_count_full = 1;
            #10;
        end
        i_count_full = 0;

        // PARITY
        i_p_state = 3'b011;
        i_rx_in = flip_parity ? ~parity_bit : parity_bit;
        #10;

        // STOP
        i_p_state = 3'b100;
        #10;

        // Check result
        if (o_parity_flag === exp_flag) begin
            $display("PASS: mode=%b, parity_bit=%b, flip=%0d, expected=%b, got=%b",
                mode, parity_bit, flip_parity, exp_flag, o_parity_flag);
            passed_tests++;
        end else begin
            $display("FAIL: mode=%b, parity_bit=%b, flip=%0d, expected=%b, got=%b",
                mode, parity_bit, flip_parity, exp_flag, o_parity_flag);
        end
    endtask

    initial begin
        reset();

        // Test case setup
        data = 8'b10110010;
        num_bits = 8;

        // NON_PARITY
        send_data(data, num_bits, 0, 3'b000, 0, 0);
        send_data(data, num_bits, 1, 3'b000, 1, 0);

        // EVEN_PARITY
        send_data(data, num_bits, calc_xor(data, num_bits), 3'b100, 0, 0);
        send_data(data, num_bits, calc_xor(data, num_bits), 3'b100, 1, 1); //FAIL

        // ODD_PARITY
        send_data(data, num_bits, ~calc_xor(data, num_bits), 3'b101, 0, 0);
        send_data(data, num_bits, ~calc_xor(data, num_bits), 3'b101, 1, 1); //FAIL

        // ZERO_STICK
        send_data(data, num_bits, 0, 3'b110, 0, 0);
        send_data(data, num_bits, 0, 3'b110, 1, 1); //FAIL

        // ONE_STICK
        send_data(data, num_bits, 1, 3'b111, 0, 0);
        send_data(data, num_bits, 1, 3'b111, 1, 1); //FAIL

        // Summary
        $display("---------------------------------------------------");
        $display("TEST SUMMARY: %0d passed / %0d total", passed_tests, total_tests);
        $display("---------------------------------------------------");

        #20;
        $finish;
    end

endmodule
