module receptor_padrao (
    input logic clk = 0,
    input logic rst,
    input logic data_sr,
    output logic [7:0] data_pl,
    output logic data_pl_en,
    output logic sync
);

    logic [5:0] count_bits = 0;
    logic [5:0] count_sync = 0;

    logic [7:0] sync_word = 8'b10100101;
    logic [7:0] buffer = 0;

    typedef enum logic [1:0] {
        IDLE            = 2'b00,
        WAIT_SYNC       = 2'b01,
        READING_SYNC    = 2'b10,
        READING_PAYLOAD = 2'b11
    } state_t;

    state_t current_state = IDLE, next_state = IDLE;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state; 
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count_bits <= 0;
            count_sync <= 0;
            data_pl_en <= 0;
            sync       <= 0;
            data_pl    <= 8'b0;
            buffer     <= 8'b0;
        end else begin
            buffer <= {buffer[6:0], data_sr};
            count_bits++;
            data_pl_en <= 0;

            case (current_state)

                IDLE: begin
                    sync <= 0;

                    if (buffer == sync_word) begin
                        count_sync <= 1; 
                        count_bits <= 0; 
                    end
                end

                WAIT_SYNC: begin
                    sync <= 0;

                    if (count_bits == 48) begin
                        if (buffer == sync_word) begin
                            count_sync++;
                        end else begin
                            count_sync <= 0;
                        end
                        count_bits <= 0;
                    end
                end

                READING_SYNC: begin
                    if (count_bits == 8) begin
                        if (buffer == sync_word) begin
                            sync <= 1;
                            count_sync <= 3;
                        end else begin
                            count_sync <= 0;
                            sync       <= 0;
                        end
                        count_bits <= 0;
                    end
                end

                READING_PAYLOAD: begin
                    sync <= 1;

                    if (count_bits % 8 == 0) begin
                        data_pl    <= buffer;
                        data_pl_en <= 1;
                    end

                    if (count_bits == 40) count_bits <= 0;
                    // $display("Time: %0t | Byte Captured! count_bits = %0d | buffer = 0x%h", 
                    //         $time, count_bits, {buffer[6:0], data_sr});

                end

            endcase
        end
    end

    always_comb begin 
        
        case (current_state)

            IDLE: begin
                if (count_sync == 1) begin
                    next_state = WAIT_SYNC;
                end else begin
                    next_state = IDLE;
                end
            end

            WAIT_SYNC: begin
                if (count_bits == 48) begin
                    if (buffer == sync_word) begin
                        if (count_sync == 3) next_state = READING_PAYLOAD;
                    end else begin
                        next_state = IDLE; 
                    end
                end            
            end

            READING_SYNC: begin
                if (count_bits == 8) begin
                    if (buffer == sync_word) begin
                        next_state = READING_PAYLOAD;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end

            READING_PAYLOAD: begin             
                if (count_bits == 40) begin
                    next_state = READING_SYNC;
                end
            end

            default: begin
                next_state = IDLE;
            end

        endcase

        // if (next_state != current_state) $display("C:%d N:%d DATA: %h", current_state, next_state, data_pl);
        // if (count_sync > 3) $display("SYNC: %d", count_sync);
    end

endmodule
