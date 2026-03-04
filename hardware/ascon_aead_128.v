module ascon_aead_128 (
    input  wire clk, rst_n, start,
    input  wire [127:0] key, nonce,
    input  wire [63:0]  data_in,
    input  wire         data_valid, is_ad_phase, last_block, decrypt_mode,
    output reg  [63:0]  data_out,
    output reg  [127:0] tag,
    output reg          valid_out, ready
);

    localparam IDLE=0, INIT_PERM=1, WAIT_DATA=2, RUN_PERM_6=3, FINALIZE=4, FINAL_PERM=5, DONE=6;
    reg [3:0] state;
    reg [3:0] round_cnt;
    reg [63:0] x0, x1, x2, x3, x4;
    reg [127:0] key_reg;
    
    // --- BIẾN MỚI: Cờ nhớ block cuối của AD ---
    reg ad_last_flag; 
    // ------------------------------------------

    wire [63:0] x0_n, x1_n, x2_n, x3_n, x4_n;
    wire [3:0]  perm_idx; 

    // Logic chọn round: Nếu đang chạy P6 thì cộng thêm offset 6
    assign perm_idx = (state == RUN_PERM_6) ? (round_cnt + 4'd6) : round_cnt;

    ascon_permutation u_perm (
        .x0_in(x0), .x1_in(x1), .x2_in(x2), .x3_in(x3), .x4_in(x4), .round_idx(perm_idx),
        .x0_out(x0_n), .x1_out(x1_n), .x2_out(x2_n), .x3_out(x3_n), .x4_out(x4_n)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; ready <= 1; valid_out <= 0; round_cnt <= 0;
            x0<=0; x1<=0; x2<=0; x3<=0; x4<=0;
            ad_last_flag <= 0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1; valid_out <= 0; ad_last_flag <= 0;
                    if (start) begin
                        x0<=64'h80400c0600000000; x1<=key[127:64]; x2<=key[63:0]; x3<=nonce[127:64]; x4<=nonce[63:0];
                        key_reg <= key; ready <= 0; state <= INIT_PERM; round_cnt <= 0;
                    end
                end

                INIT_PERM: begin
                    if (round_cnt == 11) begin
                        x0<=x0_n; x1<=x1_n; x2<=x2_n; x3<=x3_n^key_reg[127:64]; x4<=x4_n^key_reg[63:0];   
                        state <= WAIT_DATA; ready <= 1; round_cnt <= 0;
                    end else begin
                        x0<=x0_n; x1<=x1_n; x2<=x2_n; x3<=x3_n; x4<=x4_n; round_cnt<=round_cnt+1;
                    end
                end
                
                WAIT_DATA: begin
                    valid_out <= 0;
                    // Reset cờ mỗi khi quay lại chờ để an toàn
                    ad_last_flag <= 0; 

                    if (data_valid) begin
                        ready <= 0;
                        if (is_ad_phase) begin
                            // --- XỬ LÝ AD ---
                            x0 <= x0 ^ data_in; 
                            state <= RUN_PERM_6;
                            // Nếu đây là block cuối của AD, bật cờ nhớ lên
                            if (last_block) ad_last_flag <= 1; 
                        end else begin
                            // --- XỬ LÝ DATA (Plaintext / Ciphertext) ---
                            if (!decrypt_mode) begin 
                                data_out <= x0 ^ data_in; x0 <= x0 ^ data_in; 
                            end else begin 
                                data_out <= x0 ^ data_in; x0 <= data_in; 
                            end
                            
                            valid_out <= 1; 
                            
                            // Nếu hết Data thì về đích luôn, ngược lại chạy P6
                            if (last_block) state <= FINALIZE; 
                            else state <= RUN_PERM_6;
                        end
                        round_cnt <= 0;
                    end 
                    // Đã loại bỏ đoạn "else if (last_block)" cũ
                end
                
                RUN_PERM_6: begin
                    valid_out <= 0; 
                    if (round_cnt == 5) begin
                        // Cập nhật trạng thái sau vòng 6
                        x0<=x0_n; x1<=x1_n; x2<=x2_n; x3<=x3_n; 
                        
                        // --- LOGIC DOMAIN SEPARATION MỚI ---
                        // Nếu cờ bật -> XOR 1 vào x4 ngay lập tức
                        if (ad_last_flag) begin
                            x4 <= x4_n ^ 64'h1;
                        end else begin
                            x4 <= x4_n;
                        end
                        // -----------------------------------
                        
                        state <= WAIT_DATA; ready <= 1; round_cnt <= 0;
                        ad_last_flag <= 0; // Xóa cờ sau khi dùng xong
                    end else begin
                        x0<=x0_n; x1<=x1_n; x2<=x2_n; x3<=x3_n; x4<=x4_n; round_cnt<=round_cnt+1;
                    end
                end

                FINALIZE: begin
                    valid_out <= 0; 
                    x1 <= x1 ^ key_reg[127:64]; x2 <= x2 ^ key_reg[63:0];
                    state <= FINAL_PERM; round_cnt <= 0;
                end

                FINAL_PERM: begin
                    if (round_cnt == 11) begin
                        tag <= { x3_n ^ key_reg[127:64], x4_n ^ key_reg[63:0] };
                        // Cập nhật state lần cuối (optional)
                        x0<=x0_n; x1<=x1_n; x2<=x2_n;
                        x3 <= x3_n ^ key_reg[127:64]; 
                        x4 <= x4_n ^ key_reg[63:0];
                        state <= DONE;
                    end else begin
                        x0<=x0_n; x1<=x1_n; x2<=x2_n; x3<=x3_n; x4<=x4_n; round_cnt<=round_cnt+1;
                    end
                end

                DONE: begin
                    ready <= 1; valid_out <= 1; 
                    if (!start) state <= IDLE; 
                end
            endcase
        end
    end
endmodule