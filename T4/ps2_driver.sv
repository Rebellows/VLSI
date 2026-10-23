module ps2_driver
(
    input  logic clock_in,
    input  logic reset_in,
    input  logic clock_ps2,
    input  logic data_ps2,
    output logic data_p_en,
    output logic [7:0] data_p
);

    function automatic logic [7:0] scancode_to_ascii(input logic [7:0] scancode_in);

        logic [7:0] ascii_out;

        case (scancode_in)
            // ---- Digits ----
            8'h45: ascii_out = 8'h30; // 0
            8'h16: ascii_out = 8'h31; // 1
            8'h1E: ascii_out = 8'h32; // 2
            8'h26: ascii_out = 8'h33; // 3
            8'h25: ascii_out = 8'h34; // 4
            8'h2E: ascii_out = 8'h35; // 5
            8'h36: ascii_out = 8'h36; // 6
            8'h3D: ascii_out = 8'h37; // 7
            8'h3E: ascii_out = 8'h38; // 8
            8'h46: ascii_out = 8'h39; // 9

            // ---- Letters ----
            8'h1C: ascii_out = 8'h41; // A
            8'h32: ascii_out = 8'h42; // B
            8'h21: ascii_out = 8'h43; // C
            8'h23: ascii_out = 8'h44; // D
            8'h24: ascii_out = 8'h45; // E
            8'h2B: ascii_out = 8'h46; // F
            8'h34: ascii_out = 8'h47; // G
            8'h33: ascii_out = 8'h48; // H
            8'h43: ascii_out = 8'h49; // I
            8'h3B: ascii_out = 8'h4A; // J
            8'h42: ascii_out = 8'h4B; // K
            8'h4B: ascii_out = 8'h4C; // L
            8'h3A: ascii_out = 8'h4D; // M
            8'h31: ascii_out = 8'h4E; // N
            8'h44: ascii_out = 8'h4F; // O
            8'h4D: ascii_out = 8'h50; // P
            8'h15: ascii_out = 8'h51; // Q
            8'h2D: ascii_out = 8'h52; // R
            8'h1B: ascii_out = 8'h53; // S
            8'h2C: ascii_out = 8'h54; // T
            8'h3C: ascii_out = 8'h55; // U
            8'h2A: ascii_out = 8'h56; // V
            8'h1D: ascii_out = 8'h57; // W
            8'h22: ascii_out = 8'h58; // X
            8'h35: ascii_out = 8'h59; // Y
            8'h1A: ascii_out = 8'h5A; // Z

            default: ascii_out = 8'hFF;
        endcase

        return ascii_out;

    endfunction

    typedef enum logic [1:0] {
        IDLE            = 2'b00,
        READING         = 2'b01,
        WRITE           = 2'b10,
        WRITING         = 2'b11
    } state_t;

    state_t current_state, next_state;

    logic [3:0]  bit_counter;
    logic        xor_result, writed, waited;
    logic [7:0]  buffer;

    logic [2:0] clk_sync;
    logic [1:0] data_sync;
    logic       ps2_fall;   
    logic       data_s;     

    always_ff @(posedge clock_in or posedge reset_in) begin
        if (reset_in) begin
            clk_sync  <= 3'b111;   
            data_sync <= 2'b11;
        end else begin
            clk_sync  <= {clk_sync[1:0], clock_ps2};
            data_sync <= {data_sync[0], data_ps2};
        end
    end

    assign ps2_fall = clk_sync[2] & ~clk_sync[1];
    assign data_s   = data_sync[1];

    always_ff @(posedge clock_in or posedge reset_in) begin
        if (reset_in) begin
            current_state  <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    always_ff @(posedge clock_in or posedge reset_in) begin
        if (reset_in) begin
            bit_counter    <= 0;
            xor_result     <= 0;
            buffer         <= 0;
            data_p_en      <= 0;
            data_p         <= 0;
            writed         <= 0;
            waited         <= 0;
        end else begin

            case (current_state)

                IDLE: begin
                    bit_counter    <= 0;
                    xor_result     <= 0;
                    buffer         <= 0;
                    data_p_en      <= 0;
                    writed         <= 0;
                    waited         <= 0;
                end

                READING: begin
                    if (ps2_fall) begin
                        if (bit_counter < 8) begin
                            xor_result <= xor_result ^ data_s;
                            buffer[bit_counter] <= data_s;
                        end
                        bit_counter <= bit_counter + 1;
                    end
                end

                WRITE: begin
                    if (!writed) begin
                        data_p         <= scancode_to_ascii(buffer);
                        data_p_en      <= 1;
                        writed         <= 1;
                        waited         <= 0;   
                    end 
                end

                WRITING: begin
                    data_p_en <= 0;
                    waited    <= 1;
                end

                default: begin
                    bit_counter    <= 0;
                    xor_result     <= 0;
                    buffer         <= 0;
                    data_p_en      <= 0;
                    writed         <= 0;
                end

            endcase
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)

            IDLE: begin
                if (ps2_fall && (data_s == 0)) next_state = READING;
            end

            READING: begin
                if (ps2_fall) begin
                    if (bit_counter == 8) begin
                        // Check odd parity: data bits XOR parity must be 1
                        if (xor_result ^ data_s)
                            next_state = READING;
                        else
                            next_state = IDLE;
                    end
                    else if (bit_counter == 9) begin
                        // Stop bit is valid only when it is 1
                        if (data_s)
                            next_state = WRITE;
                        else
                            next_state = IDLE;
                    end
                end
            end

            WRITE: begin
                if (writed) next_state = WRITING;
            end

            WRITING: begin
                if (waited) next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase

    end

endmodule
