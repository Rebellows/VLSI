`timescale 1ns/1ps

module receptor_padrao_tb;

    localparam time CLK_PERIOD = 10ns;

	logic clk_in = 0;
	logic rst_in;
	logic data_sr_in;
	logic [7:0] data_pl_out;
	logic data_pl_en_out;
	logic sync_out;

    logic [7:0] sync_word = 8'b10100101;
    logic sync_out_ant = 0;

    always #(CLK_PERIOD / 2) clk_in = ~clk_in;

    receptor_padrao receptor_tb
    (
        .clk(clk_in),
        .rst(rst_in),
        .data_sr(data_sr_in),
        .data_pl(data_pl_out),
        .data_pl_en(data_pl_en_out),
        .sync(sync_out)
    );

    task automatic send_data(input logic [7:0] data);
        for (int i = 7; i >= 0; i--)
        begin
            data_sr_in = data[i];
            @(posedge clk_in);
        end
    endtask

    task automatic send_frame(input logic sync, input logic [39:0] payload);
        
        if (sync) send_data(sync_word);
        else send_data(~sync_word);

        for (int i = 4; i >= 0; i--)
        begin
            send_data(payload[i*8+:8]);
        end
    endtask

    always @(posedge data_pl_en_out) begin
        $display("Time: %0t | Data Parallel Out: %h", $time, data_pl_out);
    end

    always @(sync_out) begin
        $display("Time: %0t | Sync Status Changed: %b", $time, sync_out);
    end

    initial
    begin
        rst_in = 0;
        data_sr_in = 0;

        #15;
        rst_in = 1;
        #15;
        rst_in = 0;

        for (int i = 0; i < 3; i++)
        begin
            send_frame(1, 40'hAABBCCDDEE);
        end

        send_frame(0, 40'hAABBCCDDEE);

        send_frame(1, 40'h1122334455);
        send_frame(1, 40'h66778899AA);
        send_frame(1, 40'hBBCCDDEEFF);
        send_data(8'b00001111);
        send_frame(1, 40'h6767676767);

        #100;
        $finish;

    end

endmodule