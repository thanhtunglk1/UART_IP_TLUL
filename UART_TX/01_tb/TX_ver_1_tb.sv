module tb_uart_tx;

    // Parameters
    localparam CLK_PERIOD = 20; // 50 MHz clock (20 ns period)
    localparam BAUD_RATE = 115200; // Baud rate for simulation
    localparam OV_SAMP = 16; // Oversampling factor
    localparam real BAUD_PERIOD = (10**9)/ BAUD_RATE; // Baud period in ns (104166.67 ns)
    localparam real SAMPLE_PERIOD = BAUD_PERIOD / OV_SAMP; // Sample period in ns (~6510.42 ns)

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

    baud_gen #(.BAUD_WIDTH(24)) baud (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_brd_value(24'd26), // 115200 baud rate for 50MHz clock
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

    initial begin
        // Initialize signals
        i_rst_n = 0;
        i_tx_en = 1;
        i_fifo_tx_emty = 0; // FIFO is empty
        i_data = 8'b01010100; // 8'h55
        i_parity_sel = 3'b101; // No parity
        i_stop_sel = 1; // 1 stop bit
        i_width_sel = 2'b11; // 8-bit data

        // Reset the DUT
        $display("Resetting DUT...");
        #10;
        i_rst_n = 1;

        $display("Reset complete. Starting test cases...");
        if(o_tx == 1'b1) begin
            $display("Reset successful: IDLE out 1");
        end else begin 
            $display("Reset failed: expected 1, got %0b", o_tx);
        end

        $display("TEST 1: TRANSMIT 8'h55 (01010101) with 1 stop bit and no parity");
        // IDLE STATE 
        #(BAUD_PERIOD);
        if(o_tx == 1'b1) begin
            $display("IDLE out 0 transmitted successfully: %0b", o_tx);
        end else begin 
            $display("IDLE out 0 transmission failed: expected 1, got %0b", o_tx);
        end

        // START STATE (NEGEDGE) Output 0
        #(BAUD_PERIOD);
        if(o_tx == 1'b0) begin
            $display("Start bit transmitted successfully: %0b", o_tx);
        end else begin 
            $display("Start bit transmission failed: expected 0, got %0b", o_tx);
        end

        for(int i = 0; i < 8; i++) begin
            // Wait for the baud clock to stabilize
            //@(posedge i_clk);
            #(BAUD_PERIOD);
            if(o_tx == i_data[i]) begin
                $display("Data bit %0d transmitted successfully: %0b", i, o_tx);
            end else begin
                $display("Data bit %0d transmission failed: expected %0b, got %0b", i, i_data[i], o_tx);
            end
        end
        
        i_data = 8'b10101010; // 8'hAA

        #(BAUD_PERIOD); // Wait for a baud periods to simulate stop bits
        if(o_tx == 1'b1) begin
            $display("Stop bit transmitted successfully: %0b", o_tx);
        end else begin
            $display("Stop bit transmission failed: expected 1, got %0b", o_tx);
        end
        i_fifo_tx_emty = 1; // FIFO is empty
        

    //------------------------------------------------------------------------
        //TEST CASE 2: TRANSMIT 8'hAA (10101010) with 1 stop bit and no parity    
        //NEXT TRANSMISSION
        $display("TEST 2: TRANSMIT 8'hAA (10101010) with 1 stop bit and no parity");
        

        //#(BAUD_PERIOD); // Wait for 1 baud period
        if(o_tx == 1'b1) begin
            $display("IDLE out 0 transmitted successfully: %0b", o_tx);
        end else begin 
            $display("IDLE out 0 transmission failed: expected 1, got %0b", o_tx);
        end

        // START STATE (NEGEDGE) Output 0
        #(BAUD_PERIOD);
        if(o_tx == 1'b0) begin
            $display("Start bit transmitted successfully: %0b", o_tx);
        end else begin 
            $display("Start bit transmission failed: expected 0, got %0b", o_tx);
        end

        for(int i = 0; i < 8; i++) begin
            // Wait for the baud clock to stabilize
            //@(posedge i_clk);
            #(BAUD_PERIOD);
            if(o_tx == i_data[i]) begin
                $display("Data bit %0d transmitted successfully: %0b", i, o_tx);
            end else begin
                $display("Data bit %0d transmission failed: expected %0b, got %0b", i, i_data[i], o_tx);
            end
        end

        #(BAUD_PERIOD); // Wait for a baud periods to simulate stop bits
        if(o_tx == 1'b1) begin
            $display("Stop bit transmitted successfully: %0b", o_tx);
        end else begin
            $display("Stop bit transmission failed: expected 1, got %0b", o_tx);
        end



        #(BAUD_PERIOD); // Wait for 1 baud period
        if(o_tx == 1'b1) begin
            $display("IDLE out 1 transmitted successfully: %0b", o_tx);
        end else begin 
            $display("IDLE out 1 transmission failed: expected 1, got %0b", o_tx);
        end
               
        
        // Finish simulation after transmission is done
        #1000000;
        $finish;
    end

    endmodule