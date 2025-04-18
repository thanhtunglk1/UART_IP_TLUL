module syn_fifo_tb;

  parameter DEPTH = 16;
  parameter WIDTH = 8;

  logic i_clk;
  logic i_rst_n;
  logic i_wr_en;
  logic i_rd_en;
  logic [WIDTH - 1:0] data_in;
  logic [WIDTH - 1:0] data_out;
  logic o_full;
  logic o_empty;

  // Instantiate the FIFO
  syn_fifo #(.DEPTH(DEPTH), .WIDTH(WIDTH)) dut (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_wr_en(i_wr_en),
    .i_rd_en(i_rd_en),
    .i_data_in(data_in),
    .o_data_out(data_out),
    .o_full(o_full),
    .o_empty(o_empty)
  );

  initial begin 
    $shm_open("waves.shm");
    $shm_probe("ASM");
  end

  // Clock generation
  always #5 i_clk = ~i_clk;

  initial begin
    $display("--------------------[TEST] Simulation Started--------------------");
    // Initialize signals
    i_clk   = 0;
    i_rst_n = 0;
    i_wr_en = 0;
    i_rd_en = 0;
    data_in = 0;
    
    // Reset sequence
    #10 i_rst_n = 1;
    $display("[TEST] Reset completed");

    // Test writing to FIFO until full
    $display("--------------------[TEST] Writing to FIFO until full--------------------");
    for (int i = 0; i <= DEPTH; i++) begin
      @(posedge i_clk);
      if (!o_full) begin
        #1
        i_wr_en = 1;
        data_in = i;
      end else begin
        #1
        i_wr_en = 0;
      end
    end

    if (o_full) $display("PASS: FIFO is full");
    else $display("FAIL: FIFO should be full");

    #40

    // Test writing when full
    $display("--------------------[TEST] Writing when FIFO is full--------------------");
    @(posedge i_clk);
    #1
    i_wr_en = 1;
    data_in = 99;
    @(posedge i_clk);
    #1
    i_wr_en = 0;
    if (o_full) $display("PASS: FIFO prevents writing when full");
    else $display("FAIL: FIFO allows writing when full");

    #40   

    // Test reading from FIFO until empty
    $display("--------------------[TEST] Reading from FIFO until empty--------------------");
    for (int i = 0; i <= DEPTH; i++) begin
      @(posedge i_clk);
      if (!o_empty) begin
        #1
        i_rd_en = 1;
      end else begin
        #1
        i_rd_en = 0;
      end
    end
    #1
    if (o_empty) $display("PASS: FIFO is empty");
    else $display("FAIL: FIFO should be empty");

    #40
    
    // Test reading when empty
    $display("--------------------[TEST] Reading when FIFO is empty--------------------");
    @(posedge i_clk);
    #1
    i_rd_en = 1;
    @(posedge i_clk);
    #1
    i_rd_en = 0;
    if (o_empty) $display("PASS: FIFO prevents reading when empty");
    else $display("FAIL: FIFO allows reading when empty");
    
    #40

    // Alternating write and read
    $display("--------------------[TEST] Alternating Write and Read---------------------");
    for (int i = 0; i < 10; i++) begin
      @(posedge i_clk);
      #1
      i_wr_en = 1;
      data_in = i;
      @(posedge i_clk);
      #1
      i_wr_en = 0;
      i_rd_en = 1;
      @(posedge i_clk);
      #1
      i_rd_en = 0;
      if (data_out == i) $display("PASS: Correct data read %d", i);
      else $display("FAIL: Incorrect data read %d (expected %d)", data_out, i);
    end
    
  #40

    // Test random write/read sequences
    $display("--------------------[TEST] Random Write/Read Sequences--------------------");
    for (int i = 0; i < 50; i++) begin
      @(posedge i_clk);
      #1
      i_wr_en = ($random % 2);
      i_rd_en = ($random % 2);
      if (i_wr_en) data_in = $random % 1024;
    end
    
    // Edge case: Write and read simultaneously when FIFO is partially filled
    $display("--------------------[TEST] Simultaneous Write and Read--------------------");
    i_wr_en = 1;
    data_in = 55;
    i_rd_en = 1;
    @(posedge i_clk);
    #1
    i_wr_en = 0;
    i_rd_en = 0;
    @(posedge i_clk);
    #1
    if (data_out == 55) $display("PASS: Read after simultaneous write correctly");
    else $display("FAIL: Read after simultaneous write incorrect");
    
    // Stress test: Fill and empty the FIFO multiple times
    $display("--------------------[TEST] Stress Test - Multiple Fill and Empty Cycles--------------------");
    for (int cycle = 0; cycle < 3; cycle++) begin
      for (int i = 0; i < DEPTH; i++) begin
        @(posedge i_clk);
        #1
        i_wr_en = 1;
        data_in = i;
      end
      i_wr_en = 0;
      @(posedge i_clk);
      #1
      if (o_full) $display("PASS: FIFO is full in cycle %d", cycle);
      else $display("FAIL: FIFO should be full in cycle %d", cycle);
      
      for (int i = 0; i < DEPTH; i++) begin
        @(posedge i_clk);
        #1
        i_rd_en = 1;
      end
      i_rd_en = 0;
      @(posedge i_clk);
      #1
      if (o_empty) $display("PASS: FIFO is empty in cycle %d", cycle);
      else $display("FAIL: FIFO should be empty in cycle %d", cycle);
    end
    
    // Finish simulation
    #50;
    $display("--------------------[TEST] Simulation Completed---------------------");
    $finish;
  end

endmodule
