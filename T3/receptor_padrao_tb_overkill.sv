`timescale 1ns/1ps
//
// receptor_padrao_tb.sv
//
// Structured, self-checking testbench for receptor_padrao.
// Each test below is tagged with the spec requirement it targets
// (see "Trabalho 3 - Receptor de Padrao"). Every check is automatic
// (pass/fail via a running error counter) instead of relying on the
// human eyeballing $display output.
//
// NOTE (found while building this): two of the checks below (REQ_BIT_ORDER
// and REQ_STREAM_BYTE[*]) FAIL against the current RTL, and REQ_SYNC_3WORDS
// / REQ_SYNC_3WORDS_PHASE_INDEPENDENT can go either way depending on the
// exact reset-to-clock phase (both happen to pass with the two reset styles
// used below, but a different phase relationship was enough to make the
// design need a 4th alignment word instead of 3 -- see the standalone
// experiment described in the project notes). Both symptoms trace back to
// one root cause:
//
//   `count_bits++` and `count_sync++` are standalone increment statements.
//   Per the SystemVerilog LRM, that form is a BLOCKING assignment
//   (equivalent to `count_bits = count_bits + 1`), even though both sit
//   inside an otherwise-nonblocking always_ff block alongside things like
//   `count_bits <= 0` and `buffer <= {...}` (properly nonblocking). Mixing
//   blocking and nonblocking assignments to counters in the same clocked
//   block is a classic hazard: any comparison against that counter LATER
//   in the same procedural block (or in a separate always_comb sensitive
//   to it) sees the POST-increment value instead of the register's
//   start-of-cycle value, one cycle earlier than a purely-nonblocking
//   design would. Concretely:
//     - In READING_PAYLOAD, `if (count_bits % 8 == 0 && count_bits > 0)`
//       reads count_bits AFTER this cycle's blocking `count_bits++`, so
//       the byte-capture window is shifted by one bit relative to the
//       intended byte boundary. That's why the very first captured byte
//       comes out as 0x00 (a phantom capture) and every real payload byte
//       afterward reads back exactly one position late.
//     - In WAIT_SYNC, `count_sync++` similarly can make the `count_sync ==
//       3` check in the next-state logic see the incremented value in the
//       very cycle of the 3rd match, or not, depending on simulator/
//       scheduling details -- which is itself sensitive to unrelated
//       timing like the reset-to-clock phase. A synthesis tool has no
//       obligation to preserve that same-cycle ordering, so neither
//       outcome should be trusted to hold in real hardware.
//   Fix: change both to nonblocking (`count_bits <= count_bits + 1`,
//   `count_sync <= count_sync + 1`), and then re-check the comparison
//   values against the resulting one-cycle-later timing (e.g. the
//   `count_sync == 3` compare would need to become `== 2` to fire on the
//   true 3rd match, since it would now correctly read the pre-increment
//   value).
//
module receptor_padrao_tb;

    localparam time CLK_PERIOD = 10ns;

    logic clk_in = 0;
    logic rst_in;
    logic data_sr_in;
    logic [7:0] data_pl_out;
    logic data_pl_en_out;
    logic sync_out;

    logic [7:0] SYNC_WORD = 8'b10100101; // x"A5"

    always #(CLK_PERIOD / 2) clk_in = ~clk_in;

    receptor_padrao dut (
        .clk        (clk_in),
        .rst        (rst_in),
        .data_sr    (data_sr_in),
        .data_pl    (data_pl_out),
        .data_pl_en (data_pl_en_out),
        .sync       (sync_out)
    );

    // ---------------------------------------------------------------
    // Bookkeeping
    // ---------------------------------------------------------------
    int errors = 0;
    int checks = 0;

    task automatic check(input logic cond, input string msg);
        checks++;
        if (!cond) begin
            errors++;
            $display("[FAIL] t=%0t : %s", $time, msg);
        end else begin
            $display("[PASS] t=%0t : %s", $time, msg);
        end
    endtask

    // ---------------------------------------------------------------
    // Stimulus primitives
    // ---------------------------------------------------------------
    task automatic do_reset();
        rst_in = 1;
        data_sr_in = 0;
        repeat (3) @(posedge clk_in);
        rst_in = 0;
        @(posedge clk_in);
    endtask

    // Same reset, but deasserted off the clock grid (not aligned to an
    // edge) instead of synchronized to @(posedge clk_in). A correct,
    // race-free design should behave identically either way.
    task automatic do_reset_offgrid();
        rst_in = 1;
        data_sr_in = 0;
        #23;
        rst_in = 0;
        #7;
    endtask

    task automatic send_bit(input logic b);
        data_sr_in = b;
        @(posedge clk_in);
        #1; // let all NBA updates from this edge (DUT's always_ff blocks) settle
            // before any code resumes and reads DUT outputs/internals -- reading
            // immediately after @(posedge) in the same timestep is a classic
            // race that can observe stale (pre-update) values.
    endtask

    task automatic send_byte(input logic [7:0] data);
        for (int i = 7; i >= 0; i--) send_bit(data[i]);
    endtask

    // one full 48-bit frame: alignment word (correct or not) + 5 payload bytes
    task automatic send_frame(input logic aligned, input logic [39:0] payload);
        send_byte(aligned ? SYNC_WORD : ~SYNC_WORD);
        for (int i = 4; i >= 0; i--) send_byte(payload[i*8 +: 8]);
    endtask

    // Drives N correct frames back-to-back; robust helper used whenever a
    // test just needs "get into sync", regardless of exactly how many
    // consecutive words the current RTL happens to require.
    task automatic force_sync(input int max_frames = 6);
        int n;
        n = 0;
        while (!sync_out && n < max_frames) begin
            send_frame(1, 40'h0000000000);
            n++;
        end
    endtask

    // ---------------------------------------------------------------
    // Background monitors (run for the whole simulation)
    // ---------------------------------------------------------------
    int en_pulse_width = 0;
    int max_en_pulse_width = 0;
    bit unsynced_data_seen = 0;

    always @(posedge clk_in) begin
        #1; // settle, see note in send_bit
        if (data_pl_en_out) en_pulse_width++;
        else begin
            if (en_pulse_width > max_en_pulse_width) max_en_pulse_width = en_pulse_width;
            en_pulse_width = 0;
        end
        if (data_pl_en_out && !sync_out) unsynced_data_seen = 1;
    end

    // ===================================================================
    // TEST 1 - Async reset (spec: "reset assincrono e sensivel ao nivel
    // logico alto"; "caso o circuito receba reset, a logica de sincronismo
    // devera ser reiniciada")
    // ===================================================================
    task automatic test_reset();
        $display("\n--- TEST 1: asynchronous reset ---");
        do_reset();
        check(sync_out == 0, "REQ_RESET_SYNC0: sync is 0 right after reset");
        check(data_pl_out == 8'h00, "REQ_RESET_DATA0: data_pl is 0 right after reset");
        check(data_pl_en_out == 0, "REQ_RESET_EN0: data_pl_en is 0 right after reset");

        // get synced, then assert reset MID-STREAM (asynchronously, not on
        // a clock edge) and check sync drops immediately without waiting
        // for a clock edge
        force_sync();
        check(sync_out == 1, "precondition: sync achieved before mid-stream reset test");
        #(CLK_PERIOD * 3 + 2); // arbitrary, off the clock grid
        rst_in = 1;
        #1; // async: must react without a clock edge
        check(sync_out === 1'b0, "REQ_RESET_ASYNC: sync deasserts asynchronously (no clock edge waited)");
        #(CLK_PERIOD);
        rst_in = 0;
        @(posedge clk_in);

        // after reset, the sync process must restart from scratch: sending
        // only 1 or 2 alignment words must NOT be enough
        send_frame(1, 40'h0);
        check(sync_out == 0, "REQ_RESET_RESTART: 1 alignment word after reset is not enough to resync");
    endtask

    // ===================================================================
    // TEST 2 - Three CONSECUTIVE alignment words required, at 48-bit
    // spacing, before sync goes high (spec: "apos a identificacao de tres
    // palavras de alinhamento consecutivas, na posicao correta, o bit sync
    // devera ser colocado em nivel logico alto")
    // ===================================================================
    task automatic test_three_word_sync();
        do_reset();
        $display("\n--- TEST 2: sync requires exactly 3 consecutive alignment words ---");

        send_frame(1, 40'h0); // word #1
        check(sync_out == 0, "REQ_SYNC_AFTER1: sync still low after only 1 alignment word");

        send_frame(1, 40'h0); // word #2
        check(sync_out == 0, "REQ_SYNC_AFTER2: sync still low after only 2 alignment words");

        send_frame(1, 40'h0); // word #3 -- spec says sync must be high now
        check(sync_out == 1, "REQ_SYNC_3WORDS: sync goes high right after the 3rd consecutive alignment word (see file header note if this fails)");
    endtask

    // ===================================================================
    // TEST 2b - Same requirement as TEST 2, but with reset deasserted off
    // the clock grid instead of synchronized to an edge. A correctly
    // designed FSM should need exactly 3 words regardless of reset phase.
    // This probes for a phase-dependent hazard (see file header note).
    // ===================================================================
    task automatic test_three_word_sync_offgrid();
        do_reset_offgrid();
        $display("\n--- TEST 2b: same check, reset deasserted off the clock grid ---");

        send_frame(1, 40'h0);
        send_frame(1, 40'h0);
        send_frame(1, 40'h0);
        check(sync_out == 1, "REQ_SYNC_3WORDS_PHASE_INDEPENDENT: 3 words is enough regardless of reset-to-clock phase");
    endtask

    // ===================================================================
    // TEST 3 - Payload discarded while not synced: data_pl_en must never
    // pulse before sync is established (spec: "enquanto nao houver
    // alinhamento de dados, os dados de payload deverao ser descartados")
    // ===================================================================
    task automatic test_discard_while_unsynced();
        do_reset();
        $display("\n--- TEST 3: payload discarded while unsynced ---");
        unsynced_data_seen = 0;

        // only 2 correct frames -> per spec, must remain unsynced, and no
        // byte should ever be latched out while that's true
        send_frame(1, 40'hAABBCCDDEE);
        send_frame(1, 40'h1122334455);
        check(unsynced_data_seen == 0, "REQ_DISCARD: data_pl_en never pulses while sync=0");
    endtask

    // ===================================================================
    // TEST 4 - Bit order: first bit received is MSB (bit 7), out on data_pl
    // (spec: "a transmissao ... ocorre do bit mais significativo (7) para
    // o bit menos significativo (0)")
    // ===================================================================
    task automatic test_bit_order();
        logic [7:0] got;
        do_reset();
        $display("\n--- TEST 4: MSB-first bit order ---");
        force_sync();

        // asymmetric byte: NOT a palindrome under bit-reversal, so a
        // reversed capture is distinguishable from a correct one
        fork
            send_frame(1, {8'hC1, 24'h0, 8'h00}); // payload byte[0] (first byte) = 0xC1
            begin
                @(posedge data_pl_en_out);
                got = data_pl_out;
            end
        join
        check(got == 8'hC1, $sformatf("REQ_BIT_ORDER: first payload byte captured as 0x%0h, expected 0xC1 (0x83 would mean bit-reversed)", got));
    endtask

    // ===================================================================
    // TEST 5 - data_pl_en stays high for exactly one clock cycle per byte
    // (spec: "o bit data_en deve permanecer em nivel logico alto somente
    // durante um ciclo do master clock")
    // ===================================================================
    task automatic test_pulse_width();
        do_reset();
        $display("\n--- TEST 5: data_pl_en pulse width == 1 cycle ---");
        force_sync();
        max_en_pulse_width = 0;
        send_frame(1, 40'h1122334455);
        check(max_en_pulse_width == 1, $sformatf("REQ_EN_WIDTH: max observed data_pl_en pulse width = %0d cycles (expected 1)", max_en_pulse_width));
    endtask

    // ===================================================================
    // TEST 6 - Once synced, every one of the 5 payload bytes of several
    // consecutive frames is parallelized correctly, in order.
    // ===================================================================
    task automatic test_multi_frame_streaming();
        logic [7:0] expected_bytes [0:14];
        int idx;
        do_reset();
        $display("\n--- TEST 6: correct byte capture across multiple consecutive frames ---");
        force_sync();

        expected_bytes[0]=8'h11; expected_bytes[1]=8'h22; expected_bytes[2]=8'h33; expected_bytes[3]=8'h44; expected_bytes[4]=8'h55;
        expected_bytes[5]=8'h66; expected_bytes[6]=8'h77; expected_bytes[7]=8'h88; expected_bytes[8]=8'h99; expected_bytes[9]=8'hAA;
        expected_bytes[10]=8'hBB; expected_bytes[11]=8'hCC; expected_bytes[12]=8'hDD; expected_bytes[13]=8'hEE; expected_bytes[14]=8'hFF;

        idx = 0;
        fork
            begin
                send_frame(1, 40'h1122334455);
                send_frame(1, 40'h66778899AA);
                send_frame(1, 40'hBBCCDDEEFF);
            end
            begin
                repeat (15) begin
                    @(posedge data_pl_en_out);
                    check(data_pl_out == expected_bytes[idx],
                          $sformatf("REQ_STREAM_BYTE[%0d]: got 0x%0h expected 0x%0h", idx, data_pl_out, expected_bytes[idx]));
                    idx++;
                end
            end
        join
        check(sync_out == 1, "REQ_STREAM_STAYSSYNCED: sync remains high across consecutive valid frames");
    endtask

    // ===================================================================
    // TEST 7 - Loss of sync: a misaligned/incorrect alignment word after
    // sync was established must drop sync and force a full re-acquisition
    // (spec: "caso a palavra de alinhamento nao seja identificada na
    // posicao correta ..., o bit sync devera ser colocado em nivel baixo,
    // e todo o processo de recepcao devera ser reiniciado")
    // ===================================================================
    task automatic test_loss_of_sync();
        do_reset();
        $display("\n--- TEST 7: loss of sync on bad alignment word, and resync ---");
        force_sync();
        check(sync_out == 1, "precondition: sync achieved before corruption test");

        send_frame(0, 40'hDEADBEEF00); // corrupted alignment word
        check(sync_out == 0, "REQ_LOSS_OF_SYNC: sync drops after a bad alignment word");

        // must need a fresh 3-word acquisition again, not just 1
        send_frame(1, 40'h0);
        check(sync_out == 0, "REQ_RESYNC_NOT_IMMEDIATE: 1 good word right after loss-of-sync is not enough");

        force_sync();
        check(sync_out == 1, "REQ_RESYNC: design can re-acquire sync after loss");
    endtask

    // ===================================================================
    // TEST 8 - "Data suspended by the transmitter" while synced (spec
    // mentions this alongside misalignment as a desync trigger). The
    // interface has no separate valid/framing line, so the closest
    // testable proxy is: the line stops toggling (stuck level) exactly
    // where an alignment word is expected. This must also desync, and
    // the design must not hang.
    // ===================================================================
    task automatic test_data_suspended();
        do_reset();
        $display("\n--- TEST 8: line held constant where an alignment word is expected ---");
        force_sync();
        check(sync_out == 1, "precondition: sync achieved before suspension test");

        for (int i = 0; i < 8; i++) send_bit(1'b0); // stuck low instead of an alignment word
        check(sync_out == 0, "REQ_SUSPENDED: a constant/frozen line where an alignment word is due also drops sync");
    endtask

    // ===================================================================
    initial begin
        test_reset();
        test_three_word_sync();
        test_three_word_sync_offgrid();
        test_discard_while_unsynced();
        test_bit_order();
        test_pulse_width();
        test_multi_frame_streaming();
        test_loss_of_sync();
        test_data_suspended();

        $display("\n=====================================================");
        $display(" SUMMARY: %0d / %0d checks passed (%0d failed)", checks - errors, checks, errors);
        $display("=====================================================");
        $finish;
    end

endmodule
