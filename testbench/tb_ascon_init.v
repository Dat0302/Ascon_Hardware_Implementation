`timescale 1ns / 1ps

module tb_ascon_init;

    // --- 1. Khai báo tín hiệu ---
    reg clk;
    reg rst_n;
    reg start;
    reg [127:0] key;
    reg [127:0] nonce;
    
    // Các tín hiệu Data (chưa dùng đến ở bước Init, gán 0 cho sạch)
    reg [63:0] data_in = 0;
    reg data_valid = 0;
    reg is_ad_phase = 0;
    reg last_block = 0;
    reg decrypt_mode = 0;

    // Outputs (để kết nối module, không cần check ở đây)
    wire [63:0] data_out;
    wire [127:0] tag;
    wire valid_out;
    wire ready;

    // --- 2. Kết nối Module ASCON (DUT) ---
    ascon_aead_128 uut (
        .clk(clk), 
        .rst_n(rst_n), 
        .start(start), 
        .key(key), 
        .nonce(nonce), 
        .data_in(data_in), 
        .data_valid(data_valid), 
        .is_ad_phase(is_ad_phase), 
        .last_block(last_block), 
        .decrypt_mode(decrypt_mode), 
        .data_out(data_out), 
        .tag(tag), 
        .valid_out(valid_out), 
        .ready(ready)
    );

    // --- 3. Tạo xung Clock (10ns) ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- 4. Main Test Sequence ---
    initial begin
        // A. Cài đặt giá trị Input (Khớp với code C của bạn)
        key   = 128'h000102030405060708090A0B0C0D0E0F;
        nonce = 128'h000102030405060708090A0B0C0D0E0F;
        
        // Reset hệ thống
        rst_n = 0; start = 0;
        #20;
        rst_n = 1;
        #20;

        $display("===========================================");
        $display("      ASCON INITIALIZATION CHECK           ");
        $display("===========================================");

        // B. Gửi lệnh Start
        $display("[Time %0t] Starting Initialization...", $time);
        start = 1;
        @(posedge clk); // Giữ start 1 chu kỳ
        start = 0;

        // C. Chờ Module chạy xong Init (State 1 -> State 2)
        // State 1: INIT_PERM
        // State 2: WAIT_DATA
        wait (uut.state == 2); 
        
        // Chờ thêm 1 chút cho tín hiệu ổn định hẳn
        #5;

        // D. IN KẾT QUẢ TRẠNG THÁI (State Dump)
        $display("\n[Time %0t] --- STATE AFTER INIT (P12) ---", $time);
        // Lưu ý: %h in ra hex, %016h đảm bảo đủ 16 ký tự hex (64 bit)
        $display("x0: %016h", uut.x0);
        $display("x1: %016h", uut.x1);
        $display("x2: %016h", uut.x2);
        $display("x3: %016h", uut.x3);
        $display("x4: %016h", uut.x4);
        $display("-------------------------------------------");
        
        // Kết thúc mô phỏng
        $finish;
    end

endmodule