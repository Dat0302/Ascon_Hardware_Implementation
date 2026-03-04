`timescale 1ns / 1ps

module tb_ascon_aead_128;

    reg clk, rst_n, start, data_valid, is_ad_phase, last_block, decrypt_mode;
    reg [127:0] key, nonce;
    reg [63:0] data_in;
    wire [63:0] data_out;
    wire [127:0] tag;
    wire valid_out, ready;

    integer ct_block_count;

    // Test Vectors
    parameter [127:0] KEY_VAL   = 128'h000102030405060708090A0B0C0D0E0F;
    parameter [127:0] NONCE_VAL = 128'h000102030405060708090A0B0C0D0E0F;
    parameter [63:0] AD_DATA = 64'h1122334455667788;
    parameter [63:0] PT_DATA = 64'hAABBCCDDEEFF0011;
    parameter [63:0] PAD_BLK = 64'h8000000000000000;

    ascon_aead_128 uut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .key(key), .nonce(nonce),
        .data_in(data_in), .data_valid(data_valid),
        .is_ad_phase(is_ad_phase), .last_block(last_block),
        .decrypt_mode(decrypt_mode),
        .data_out(data_out), .tag(tag), .valid_out(valid_out), .ready(ready)
    );

    initial begin clk=0; forever #5 clk=~clk; end

    // Task in trạng thái (Debug)
    task print_state(input [8*30:1] label);
    begin
            $display("\n--- %s ---", label);
            $display("x0: %016h", uut.x0);
            $display("x1: %016h", uut.x1);
            $display("x2: %016h", uut.x2);
            $display("x3: %016h", uut.x3);
            $display("x4: %016h", uut.x4);
    end
    endtask

    // Task gửi Block THƯỜNG (Có chờ Ready)
    task send_block_normal(input [63:0] blk_data);
    begin
        wait(ready == 1'b1); @(posedge clk);
        data_in = blk_data; data_valid = 1; last_block = 0;
        
        // Giữ Valid 1 chu kỳ, sau đó hạ xuống (Master behavior)
        @(posedge clk); 
        data_valid = 0; 
        
        // Chờ module bận rồi chờ module rảnh lại
        wait(ready == 0); wait(ready == 1);
    end
    endtask

    // Task gửi Block CUỐI CÙNG (Dùng cho cả AD và Data)
    task send_block_final(input [63:0] blk_data);
    begin
        wait(ready == 1'b1); @(posedge clk);
        data_in = blk_data; 
        data_valid = 1;
        last_block = 1; // Bật cờ Last lên CÙNG LÚC với Valid
        
        @(posedge clk); 
        data_valid = 0; 
        last_block = 0; // Hạ ngay lập tức (Test độ cứng của Design)
        
        wait(ready == 0); wait(ready == 1);
    end
    endtask

    // --- ĐÃ XÓA TASK trigger_domain_sep_ad ---
    // Vì bây giờ Domain Sep tự động xảy ra khi gửi last block của AD

    initial begin
        rst_n = 0;
        start = 0; key = 0; nonce = 0;
        data_in = 0; data_valid = 0; is_ad_phase = 0;
        last_block = 0; decrypt_mode = 0;
        ct_block_count = 0;
        
        #50 rst_n = 1;
        #20;

        $display("=== ASCON OPTIMIZED TIMING TEST ===");

        // 1. Init
        wait(ready); @(posedge clk);
        start = 1; key = KEY_VAL; nonce = NONCE_VAL;
        ct_block_count = 0;
        @(posedge clk); start = 0;
        wait(ready == 0); wait(ready == 1);
        print_state("AFTER INIT");

        // 2. AD Phase
        $display("\n--- SENDING AD ---");
        is_ad_phase = 1;
        
        // Gửi block AD đầu (bình thường)
        send_block_normal(AD_DATA); 
        
        // Gửi block AD cuối (Padding) -> Bật last_block = 1 tại đây
        // Module sẽ tự động hấp thụ, bật cờ nhớ, chạy P6, XOR Domain Sep và quay về.
        send_block_final(PAD_BLK); 
        
        print_state("AFTER AD (Should have Domain Sep XOR)");

        // 3. PT Phase
        $display("\n--- SENDING PLAINTEXT ---");
        is_ad_phase = 0; // Chuyển sang phase Data
        
        // Block 1 (Bình thường)
        send_block_normal(PT_DATA);
        
        // Block 2 (Cuối cùng - Padding) -> Bật last_block = 1
        // Module sẽ mã hóa block này rồi nhảy thẳng sang FINALIZE
        send_block_final(PAD_BLK);

        // 4. CHỜ KẾT QUẢ
        wait(valid_out == 1'b1);
        @(posedge clk);

        $display("\n=================================");
        $display(" FINAL CHECK DONE");
        $display("=================================");
        
        #50 $finish;
    end
    
    // Monitor Output
    always @(posedge clk) begin
        if (valid_out) begin
            if (ready) begin
               $display(">> [OUTPUT] TAG Generated: %h", tag);
            end 
            else if (!is_ad_phase) begin
                $display(">> [OUTPUT] Ciphertext Block #%0d: %h", ct_block_count, data_out);
                ct_block_count = ct_block_count + 1;
            end
        end
    end

endmodule