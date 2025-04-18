module uart_rx_tb;

    // Parameters
    localparam CLK_PERIOD = 20; // 50MHz clock
    localparam OV_SAMP = 16;
    localparam BAUD = 115200; // Baud rate for UART
    localparam real BAUD_PERIOD = (10**9)/BAUD; // Baud rate for 115200 bps with 50MHz clock

    // Signals
    logic i_clk, i_baud, i_rst_n;
    logic i_rx;
    logic i_fifo_full = 0;

    logic i_rx_en = 1;
    logic [2:0] i_parity_sel = 3'b000; // No parity
    logic i_stop_sel = 0;              // 1 stop bit
    logic [1:0] i_width_sel = 2'b11;   // 8-bit data

    logic o_rx_fifo_wr_en;
    logic [7:0] o_data;
    logic o_error_frame;
    logic o_error_parity;
    logic o_error_overrun;

    // DUT
    baud_gen #(.BAUD_WIDTH(24)) baud(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_brd_value(24'd26), // 115200 baud rate for 50MHz clock
        .o_baud(i_baud)
    ); 

    uart_rx #(.OV_SAMP(OV_SAMP)) uut (
        .i_clk(i_clk),
        .i_baud(i_baud),
        .i_rst_n(i_rst_n),
        .i_rx(i_rx),
        .i_fifo_full(i_fifo_full),
        .i_rx_en(i_rx_en),
        .i_parity_sel(i_parity_sel),
        .i_stop_sel(i_stop_sel),
        .i_width_sel(i_width_sel),
        .o_rx_fifo_wr_en(o_rx_fifo_wr_en),
        .o_data(o_data),
        .o_error_frame(o_error_frame),
        .o_error_parity(o_error_parity),
        .o_error_overrun(o_error_overrun)
    );

    initial begin 
        $shm_open("waves.shm");
        $shm_probe("ASM");
    end

    // Clock generator
    initial i_clk = 0;
    always #(CLK_PERIOD/2) i_clk = ~i_clk;

    // Reset and stimulus
    initial begin
        i_rst_n = 0;
        i_rx = 1; // Idle line
        #100;
        i_rst_n = 1;

        $display("Sent byte:     (0x%h) at time %0t", 8'b01010101, $time);
        // Transmit 'A' = 8'b0101_0101
        send_byte(8'b01010101); // ASCII '0x55'
        
        //@(posedge o_rx_fifo_wr_en)
        //#1;
        $display("Received byte: (0x%h) at time %0t", o_data, $time);

        $display("Sent byte:     (0x%h) at time %0t", 8'b10101010, $time);
        send_byte(8'b10101010); // ASCII '0xAA'
        //@(posedge o_rx_fifo_wr_en)
        //#1;
        $display("Received byte: (0x%h) at time %0t", o_data, $time);
        
        // Wait and finish
        #200000;
        $finish;
    end

    // Task to send a byte over serial
    task send_byte(input [7:0] data);
        integer i;
        begin
            // Start bit (0)
            @(posedge i_clk); i_rx = 0;
            #(BAUD_PERIOD);

            // Data bits (LSB first)
            for (i = 0; i < 8; i++) begin
                i_rx = data[i];
                #(BAUD_PERIOD);
            end

            // Stop bit (1)
            i_rx = 1;
            #(BAUD_PERIOD);
        end
    endtask

endmodule
