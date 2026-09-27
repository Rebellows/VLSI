module receptor_padrao (
    input logic clk = 0,
    input logic rst,
    input logic data_sr,
    output logic [7:0] data_pl,
    output logic data_pl_en,
    output logic sync
);

    logic [5:0] count_bits = 0;
    logic [1:0] count_sync = 0;

    logic [7:0] sync_word = 8'b10100101;
    logic [7:0] buffer = 0;
    logic [7:0] next_buffer;
    logic discard_payload = 0;

    typedef enum logic [1:0] {
        IDLE            = 2'b00,
        WAIT_SYNC       = 2'b01,
        READING_SYNC    = 2'b10,
        READING_PAYLOAD = 2'b11
    } state_t;

    state_t current_state = IDLE;
    state_t next_state = IDLE;

    assign next_buffer = {buffer[6:0], data_sr};

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count_bits      <= 0;
            count_sync      <= 0;
            data_pl_en      <= 0;
            sync            <= 0;
            data_pl         <= 8'b0;
            buffer          <= 8'b0;
            discard_payload <= 0;
        end else begin
            buffer     <= next_buffer;
            data_pl_en <= 0;

            case (current_state)

                IDLE: begin
                    sync       <= 0;

                    if (count_sync == 1) begin
                        count_bits <= count_bits + 1'b1;
                    end else if (next_buffer == sync_word) begin
                        count_bits <= 0;
                        count_sync <= 1;
                    end else begin
                        count_bits <= 0;
                    end
                end

                WAIT_SYNC: begin
                    sync <= 0;

                    if (count_bits == 6'd47) begin
                        count_bits <= 0;

                        if (next_buffer == sync_word) begin
                            if (count_sync == 2) begin
                                count_sync      <= 3;
                                sync            <= 1;
                                discard_payload <= 1;
                            end else begin
                                count_sync <= count_sync + 1'b1;
                            end
                        end else begin
                            count_sync <= 0;
                        end
                    end else begin
                        count_bits <= count_bits + 1'b1;
                    end
                end

                READING_SYNC: begin
                    sync <= 1;

                    if (count_bits == 6'd7) begin
                        count_bits <= 0;

                        if (next_buffer != sync_word) begin
                            count_sync <= 0;
                            sync       <= 0;
                        end
                    end else begin
                        count_bits <= count_bits + 1'b1;
                    end
                end

                READING_PAYLOAD: begin
                    sync <= 1;

                    if (!discard_payload && (((count_bits + 1'b1) % 8) == 0)) begin
                        data_pl    <= next_buffer;
                        data_pl_en <= 1;
                    end

                    if (count_bits == 6'd39) begin
                        count_bits      <= 0;
                        discard_payload <= 0;
                    end else begin
                        count_bits <= count_bits + 1'b1;
                    end
                end

                default: begin
                    count_bits      <= 0;
                    count_sync      <= 0;
                    discard_payload <= 0;
                    sync            <= 0;
                end

            endcase
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)

            IDLE: begin
                if (count_sync == 1)
                    next_state = WAIT_SYNC;
            end

            WAIT_SYNC: begin
                if (count_bits == 6'd47) begin
                    if (next_buffer == sync_word && count_sync == 2)
                        next_state = READING_PAYLOAD;
                    else if (next_buffer != sync_word)
                        next_state = IDLE;
                end
            end

            READING_SYNC: begin
                if (count_bits == 6'd7) begin
                    if (next_buffer == sync_word)
                        next_state = READING_PAYLOAD;
                    else
                        next_state = IDLE;
                end
            end

            READING_PAYLOAD: begin
                if (count_bits == 6'd39)
                    next_state = READING_SYNC;
            end

            default: begin
                next_state = IDLE;
            end

        endcase
        // if (next_state != current_state) $display("C:%d N:%d DATA: %h", current_state, next_state, data_pl);
        // if (count_sync > 3) $display("SYNC: %d", count_sync);
    end

endmodule
