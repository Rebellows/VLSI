`timescale 1ns/1ps

module ps2_driver_tb;

    localparam time CLK_PERIOD = 10ns;

    logic clock_in;
    logic reset_in;
    logic clock_ps2;
    logic data_ps2;
    logic data_p_en;
    logic [7:0] data_p;

    always #(CLK_PERIOD / 2) clock_in = ~clock_in;

    // Registra se houve pulso em data_p_en (o pulso é curto demais para ser visto depois)
    int pulsos = 0;
    always @(posedge data_p_en) pulsos++;

    ps2_driver ps2_tb (
        .clock_in(clock_in),
        .reset_in(reset_in),
        .clock_ps2(clock_ps2),
        .data_ps2(data_ps2),
        .data_p_en(data_p_en),
        .data_p(data_p)
    );

    task automatic send_ps2_packet(
        input logic [7:0] data,
        input logic       parity,
        input logic       stop_bit
    );
        // Start bit (0)
        clock_ps2 = 1;
        data_ps2  = 0;
        #40;
        clock_ps2 = 0; // Falling edge
        #40;

        // 8 Data bits (LSB first)
        for (int i = 0; i < 8; i++) begin
            clock_ps2 = 1;
            data_ps2  = data[i];
            #40;
            clock_ps2 = 0; // Falling edge
            #40;
        end

        // Parity bit
        clock_ps2 = 1;
        data_ps2  = parity;
        #40;
        clock_ps2 = 0; // Falling edge
        #40;

        // Stop bit
        clock_ps2 = 1;
        data_ps2  = stop_bit;
        #40;
        clock_ps2 = 0; // Falling edge
        #40;

        // Return bus to idle
        clock_ps2 = 1;
        data_ps2  = 1;
        #100;
    endtask

    initial begin
        // Initialize signals
        clock_in  = 0;
        reset_in  = 0;
        clock_ps2 = 1;
        data_ps2  = 1;

        #15;
        reset_in = 1;
        #15;
        reset_in = 0;
        #20;

        $display("=== Starting PS/2 Driver Testbench ===");

        // -------------------------------------------------------------
        // Test 1: All Fine (Valid Scancode 8'h1C -> ASCII 'A' = 8'h41)
        // -------------------------------------------------------------
        $display("[%0tns] Test 1: Sending valid packet (8'h1C)", $time);
        send_ps2_packet(8'h1C, 1'b0, 1'b1);

        // Validation for Test 1
        $display("[%0tns] data_p = 0x%0h (Expected: 0x41)", $time, data_p);
        assert (pulsos == 1)     else $error("Test 1 FAILED: data_p_en nunca pulsou");
        assert (data_p == 8'h41) else $error("Test 1 FAILED: Expected ASCII 0x41 ('A'), got 0x%0h", data_p);
        #200;

        // -------------------------------------------------------------
        // Test 2: Parity Wrong (Parity bit = 1 instead of 0)
        // -------------------------------------------------------------
        $display("[%0tns] Test 2: Sending packet with PARITY ERROR", $time);
        send_ps2_packet(8'h1C, 1'b1, 1'b1); // Parity bit incorrect

        #500;
        if (pulsos != 1) begin
            $error("Test 2 FAILED: data_p_en asserted despite parity error!");
        end else begin
            $display("[%0tns] Test 2 Passed: Correctly ignored packet due to parity error.", $time);
        end

        // -------------------------------------------------------------
        // Test 3: Stop Bit Error (Stop bit = 0 instead of 1)
        // -------------------------------------------------------------
        $display("[%0tns] Test 3: Sending packet with STOP BIT ERROR", $time);
        send_ps2_packet(8'h1C, 1'b0, 1'b0); // Stop bit incorrect

        #500;
        if (pulsos != 1) begin
            $error("Test 3 FAILED: data_p_en asserted despite stop bit error!");
        end else begin
            $display("[%0tns] Test 3 Passed: Correctly ignored packet due to stop bit error.", $time);
        end

        #200;
        $display("=== All Tests Finished Successfully ===");
        $finish;
    end

endmodule;
