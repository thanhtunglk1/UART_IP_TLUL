module uart_rx #( parameter OV_SAMP = 16)(
//GLOBAL
    input  logic        i_clk,
    input  logic        i_baud,         // Baud rate clock
    input  logic        i_rst_n,
//RX_INPUT
    input  logic        i_rx,           // RX from serial port
    input  logic        i_fifo_full,    // RX FIFO full signal
//CONTROL_SIGNAL
    input  logic        i_rx_en,        // Enable RX working
    input  logic [2:0]  i_parity_sel,   // NON/ODD/EVEN/0/1 bit parity
    input  logic        i_stop_sel,     // 1/2 bit stop
    input  logic [1:0]  i_width_sel,    // 5/6/7/8 bit receive
//RESPONSE_SIGNAL
    output logic        o_busy,
    output logic        o_rx_fifo_wr_en,// RX_done 
//FLAG_RESPONSE     
    output logic        o_error_frame,  // Wrong stop bit
    output logic        o_error_parity, // Wrong parity bit
);

//CONSTANTS
    localparam  MID_SAMP   = OV_SAMP/2;

    typedef enum logic [2:0] {
        IDLE,
        START,
        RECEIVER,
        PARITY,
        STOP_I,
        STOP_II
    } e_state;

//----------------------------------------------------------------------------------------------------
    logic [3:0] bit_width;

    always_comb begin: proc_decode_bit_width

        case(i_width_sel)
            2'b00: bit_width    = 4'd5; // 5 bit width
            2'b01: bit_width    = 4'd6; // 6 bit width
            2'b10: bit_width    = 4'd7; // 7 bit width
            2'b11: bit_width    = 4'd8; // 8 bit width
            default: bit_width  = 4'd8;
        endcase

    end    

//----------------------------------------------------------------------------------------------------
    logic rx_in, start_signal;

    negedge_detect rx_cdc_buffer(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_rx_serial(i_rx),
        .i_rx_en(i_rx_en),
        .i_baud(i_baud),
        .o_rx_in(rx_in),
        .o_start_signal(start_signal)
    );

//----------------------------------------------------------------------------------------------------

    e_state p_state, n_state;
    logic [3:0] p_counter, n_counter;
    logic [2:0] p_index, n_index;
    
    initial begin
        p_state = IDLE;
        p_counter = 4'b0;
        p_index = 3'b0;
    end

    always_ff @(posedge i_clk, negedge i_rst_n) begin: proc_update_state

        if(~i_rst_n) begin
            p_state   <= IDLE;
            p_counter <= 4'b0;
            p_index   <= 4'b0;
        end

        else if(i_baud) begin
            p_state   <= n_state;
            p_counter <= n_counter;
            p_index   <= n_index; 
        end 

    end

//----------------------------------------------------------------------------------------------------

    logic [3:0] count_full, count_half;
    assign count_full = (p_counter == OV_SAMP  - 1);
    assign count_half = (p_counter == MID_SAMP - 1);

    logic receive_done;
    assign receive_done = (p_index == bit_width);

    logic parity_en;
    assign parity_en = i_parity_sel[2];

    always_comb begin: proc_detect_next

        case(p_state)

            IDLE: begin
                n_state   = start_signal ? IDLE : START;
                n_counter = 4'b0;  
                n_index   = 3'b0;
            end

            START: begin
                if(count_half) n_state = rx_in ? IDLE : RECEIVER;
                else           n_state = START;
                n_counter = (count_half) ? 4'b0 : p_counter + 4'b1;
                n_index   = 3'b0;
            end

            RECEIVER: begin
                if(receive_done & count_full) n_state = parity_en ? PARITY : STOP_I;
                else                          n_state = RECEIVER; 
                n_counter = count_full ? 4'b0 : p_counter + 4'b1;
                n_index   = count_full ? p_index + 3'b1 : p_index;
            end

            PARITY: begin

            end  

            default: begin
                n_state   = IDLE;
                n_counter = 4'b0;
                n_index   = 4'b0;
            end

        endcase
    end

//----------------------------------------------------------------------------------------------------   
//STORE_RX_DATA
    logic [7:0] rx_data_buffer;
    logic [7:0] rx_data;

    always_ff @(posedge i_clk, negedge i_rst_n) begin: proc_update_state
        
        if(~i_rst_n) begin
            rx_data <= 8'b0;
        end

        else if(i_baud) begin
            if((p_state == RECEIVER) & count_full) begin
                rx_data[p_index] <= rx_in;
            end
        end

    end

//----------------------------------------------------------------------------------------------------  
//PARITY_CHECK

    parity_check parity_check(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_baud(i_baud),
        .i_rx_en(i_rx_en),
        .i_rx_in(rx_in),
        .i_count_full(count_full),
        .i_parity_sel(i_parity_sel),
        .i_p_state(p_state),
        .i_p_counter(p_counter),
        .o_parity_flag(o_error_parity)
    );


endmodule