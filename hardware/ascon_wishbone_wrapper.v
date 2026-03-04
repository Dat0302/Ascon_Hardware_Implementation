module ascon_wishbone_wrapper (
    input  wire        wb_clk_i,
    input  wire        wb_rst_i,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [6:0]  wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o,
    output wire        irq_o
);

    // ========================================
    // 1. DEFINITIONS
    // ========================================
    // Các trạng thái của máy trạng thái (FSM)
    localparam [3:0]
        WR_IDLE         = 4'd0,
        WR_INIT         = 4'd1,
        WR_WAIT_INIT    = 4'd2,
        WR_READY        = 4'd3,
        WR_SEND_DATA    = 4'd4,
        WR_WAIT_PROC    = 4'd5,
        WR_OUTPUT_VALID = 4'd6,
        WR_TAG_VALID    = 4'd7,
        WR_WAIT_TAG_GEN = 4'd8, // Trạng thái chờ Tag riêng biệt
        WR_ERROR        = 4'd15;

    reg [3:0] wrapper_state;
    
    // Địa chỉ thanh ghi (Word offset)
    localparam IDX_CTRL       = 5'h00; // 0x00
    localparam IDX_CONFIG     = 5'h01; // 0x04
    localparam IDX_DATA_IN_L  = 5'h02; // 0x08
    localparam IDX_DATA_IN_H  = 5'h03; // 0x0C
    localparam IDX_DATA_OUT_L = 5'h04; // 0x10
    localparam IDX_DATA_OUT_H = 5'h05; // 0x14
    // Key: 0x20..0x2C, Nonce: 0x30..0x3C, Tag: 0x40..0x4C

    // Các thanh ghi nội bộ
    reg [127:0] reg_key;
    reg [127:0] reg_nonce;
    reg [63:0]  reg_data_in;
    reg [63:0]  reg_data_out_buf;
    reg [127:0] reg_tag_buf;
    
    // Các thanh ghi cấu hình
    reg reg_decrypt;
    reg reg_is_ad;
    reg reg_last;
    
    // Tín hiệu bắt tay từ phần mềm (Software Handshake)
    reg sw_start_req;       
    reg sw_data_send_req;   
    reg sw_output_ack;      
    reg sw_tag_ack;         
    
    // Cờ báo trạng thái
    reg output_buffered;    
    reg tag_buffered;       
    reg error_flag;
    
    // --- [QUAN TRỌNG] Cờ nhớ Tag (Latch) ---
    // Dùng để lưu Tag nếu nó đến trong lúc Wrapper đang bận trả Data
    reg tag_latched; 

    // Tín hiệu kết nối với Core ASCON
    reg  core_start;
    reg  core_data_valid;
    wire core_ready;
    wire core_valid_out;
    wire [63:0]  core_data_out;
    wire [127:0] core_tag;
    
    // Timeout
    reg [15:0] timeout_counter;
    parameter TIMEOUT_MAX = 16'hFFFF;

    // Ngắt (nếu cần dùng)
    assign irq_o = tag_buffered;

    // ========================================
    // 2. INSTANTIATE ASCON CORE
    // ========================================
    ascon_aead_128 u_core (
        .clk(wb_clk_i),
        .rst_n(~wb_rst_i),
        .start(core_start),
        .key(reg_key),
        .nonce(reg_nonce),
        .data_in(reg_data_in),
        .data_valid(core_data_valid),
        .is_ad_phase(reg_is_ad),
        .last_block(reg_last),
        .decrypt_mode(reg_decrypt),
        .data_out(core_data_out),
        .tag(core_tag),
        .valid_out(core_valid_out),
        .ready(core_ready)
    );

    // ========================================
    // 3. MAIN STATE MACHINE
    // ========================================
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wrapper_state <= WR_IDLE;
            core_start <= 0;
            core_data_valid <= 0;
            output_buffered <= 0;
            tag_buffered <= 0;
            error_flag <= 0;
            timeout_counter <= 0;
            reg_data_out_buf <= 0;
            reg_tag_buf <= 0;
            tag_latched <= 0; // Reset cờ Latch
        end else begin
            // Mặc định tắt các tín hiệu xung (pulse)
            core_start <= 0;
            core_data_valid <= 0;
            
            case (wrapper_state)
                // --- IDLE: Chờ lệnh Start ---
                WR_IDLE: begin
                    output_buffered <= 0;
                    tag_buffered <= 0;
                    error_flag <= 0;
                    tag_latched <= 0; // Reset cho phiên mới
                    if (sw_start_req) wrapper_state <= WR_INIT;
                end

                // --- INIT: Gửi lệnh Start xuống Core ---
                WR_INIT: begin
                    core_start <= 1;
                    wrapper_state <= WR_WAIT_INIT;
                    timeout_counter <= 0;
                end

                // --- WAIT_INIT: Chờ Core báo Ready ---
                WR_WAIT_INIT: begin
                    if (core_ready) begin
                        wrapper_state <= WR_READY;
                    end else if (timeout_counter >= TIMEOUT_MAX) begin
                        error_flag <= 1;
                        wrapper_state <= WR_ERROR;
                    end else begin
                        timeout_counter <= timeout_counter + 1;
                    end
                end

                // --- READY: Chờ dữ liệu từ Software ---
                WR_READY: begin
                    if (sw_data_send_req && core_ready) begin
                        wrapper_state <= WR_SEND_DATA;
                    end
                end

                // --- SEND_DATA: Đẩy dữ liệu vào Core ---
                WR_SEND_DATA: begin
                    core_data_valid <= 1;
                    wrapper_state <= WR_WAIT_PROC;
                    timeout_counter <= 0;
                end

                // --- WAIT_PROC: Chờ Core xử lý xong ---
                WR_WAIT_PROC: begin
                    if (core_valid_out) begin
                        // [FIX] Luôn ưu tiên bắt Ciphertext (Data) trước
                        // Kể cả là block cuối, nó vẫn ra Ciphertext trước khi ra Tag.
                        reg_data_out_buf <= core_data_out;
                        output_buffered <= 1;
                        wrapper_state <= WR_OUTPUT_VALID; 
                        timeout_counter <= 0;
                    end 
                    else if (core_ready) begin
                        // Chỉ quay về Ready nếu là giai đoạn AD (không có output)
                        if (reg_is_ad) begin
                            wrapper_state <= WR_READY;
                            timeout_counter <= 0;
                        end
                        // Nếu là Encrypt/Decrypt thì phải chờ Valid (Data Output)
                    end 
                    else begin
                        // Timeout
                        if (timeout_counter >= TIMEOUT_MAX) begin
                            error_flag <= 1;
                            wrapper_state <= WR_ERROR;
                        end else timeout_counter <= timeout_counter + 1;
                    end
                end

                // --- OUTPUT_VALID: Chờ SW đọc Data & "Nghe ngóng" Tag ---
                WR_OUTPUT_VALID: begin
                    // [SNOOP LOGIC] Bắt Tag nếu nó đến sớm
                    // Trong lúc chờ SW ACK Data, Core có thể tính xong Tag.
                    // Nếu thấy Tag valid, phải lưu ngay lập tức!
                    if (core_valid_out && reg_last && !reg_is_ad && !tag_latched) begin
                        reg_tag_buf <= core_tag; 
                        tag_latched <= 1;        
                    end

                    // Xử lý ACK từ Software
                    if (sw_output_ack) begin
                        output_buffered <= 0; 
                        
                        // Điều hướng:
                        if (reg_last && !reg_is_ad) begin
                            // Nếu xong block cuối -> Chuyển sang trả Tag
                            wrapper_state <= WR_WAIT_TAG_GEN; 
                        end else begin
                            // Chưa xong -> Quay về nhận block tiếp
                            wrapper_state <= WR_READY;
                        end
                        timeout_counter <= 0;
                    end
                end

                // --- WAIT_TAG_GEN: Đợi Tag (hoặc trả Tag đã bắt được) ---
                WR_WAIT_TAG_GEN: begin
                    // TH1: Tag đã được bắt (latch) từ bước trước
                    if (tag_latched) begin
                        tag_buffered <= 1;
                        wrapper_state <= WR_TAG_VALID;
                        timeout_counter <= 0;
                        tag_latched <= 0; // Xóa cờ sau khi dùng
                    end
                    // TH2: Tag chưa đến, giờ mới đến
                    else if (core_valid_out) begin
                        reg_tag_buf <= core_tag;
                        tag_buffered <= 1;
                        wrapper_state <= WR_TAG_VALID;
                        timeout_counter <= 0;
                    end 
                    // Timeout
                    else begin
                        if (timeout_counter >= TIMEOUT_MAX) begin
                            error_flag <= 1;
                            wrapper_state <= WR_ERROR;
                        end else timeout_counter <= timeout_counter + 1;
                    end
                end

                // --- TAG_VALID: Chờ SW xác nhận đã lấy Tag ---
                WR_TAG_VALID: begin
                    if (sw_tag_ack) begin
                        tag_buffered <= 0;
                        wrapper_state <= WR_IDLE; // Xong toàn bộ, về IDLE
                    end
                end

                WR_ERROR: begin
                    error_flag <= 1; // Kẹt ở đây nếu lỗi
                end
                
                default: wrapper_state <= WR_IDLE;
            endcase
        end
    end

    // ========================================
    // 4. WISHBONE INTERFACE (WRITE)
    // ========================================
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wb_ack_o <= 0;
            reg_key <= 0;
            reg_nonce <= 0;
            reg_data_in <= 0;
            reg_decrypt <= 0;
            reg_is_ad <= 0;
            reg_last <= 0;
            sw_start_req <= 0;
            sw_data_send_req <= 0;
            sw_output_ack <= 0;
            sw_tag_ack <= 0;
        end else begin
            // Tự động xóa các cờ điều khiển sau 1 chu kỳ (Pulse)
            sw_start_req <= 0;
            sw_data_send_req <= 0;
            sw_output_ack <= 0;
            sw_tag_ack <= 0;
            wb_ack_o <= 0;

            if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
                wb_ack_o <= 1; 
                if (wb_we_i) begin
                    case (wb_adr_i[6:2])
                        IDX_CTRL: begin
                            if (wb_dat_i[0]) sw_start_req <= 1;
                            if (wb_dat_i[1]) sw_data_send_req <= 1;
                            if (wb_dat_i[2]) sw_output_ack <= 1;
                            if (wb_dat_i[3]) sw_tag_ack <= 1;
                        end
                        IDX_CONFIG: begin
                            reg_is_ad   <= wb_dat_i[0];
                            reg_last    <= wb_dat_i[1];
                            reg_decrypt <= wb_dat_i[2];
                        end
                        IDX_DATA_IN_L: reg_data_in[31:0]  <= wb_dat_i;
                        IDX_DATA_IN_H: reg_data_in[63:32] <= wb_dat_i;
                        // Key (0x20...)
                        5'd8:  reg_key[127:96] <= wb_dat_i;
                        5'd9:  reg_key[95:64]  <= wb_dat_i;
                        5'd10: reg_key[63:32]  <= wb_dat_i;
                        5'd11: reg_key[31:0]   <= wb_dat_i;
                        // Nonce (0x30...)
                        5'd12: reg_nonce[127:96] <= wb_dat_i;
                        5'd13: reg_nonce[95:64]  <= wb_dat_i;
                        5'd14: reg_nonce[63:32]  <= wb_dat_i;
                        5'd15: reg_nonce[31:0]   <= wb_dat_i;
                    endcase
                end
            end
        end
    end

    // ========================================
    // 5. WISHBONE INTERFACE (READ)
    // ========================================
    always @(*) begin
        wb_dat_o = 32'd0;
        if (wb_cyc_i && wb_stb_i && !wb_we_i) begin
            case (wb_adr_i[6:2])
                IDX_CTRL: begin
                    wb_dat_o[0] = (wrapper_state == WR_READY);
                    wb_dat_o[1] = output_buffered; // STATUS_OUT_VALID
                    wb_dat_o[2] = tag_buffered;    // STATUS_TAG_VALID
                    wb_dat_o[3] = (wrapper_state != WR_IDLE && 
                                   wrapper_state != WR_READY &&
                                   wrapper_state != WR_OUTPUT_VALID &&
                                   wrapper_state != WR_TAG_VALID); // STATUS_BUSY
                    wb_dat_o[4] = error_flag;
                end
                IDX_CONFIG: begin
                    wb_dat_o[0] = reg_is_ad;
                    wb_dat_o[1] = reg_last;
                    wb_dat_o[2] = reg_decrypt;
                end
                IDX_DATA_OUT_L: wb_dat_o = reg_data_out_buf[31:0];
                IDX_DATA_OUT_H: wb_dat_o = reg_data_out_buf[63:32];
                // Tag (0x40...)
                5'd16: wb_dat_o = reg_tag_buf[127:96];
                5'd17: wb_dat_o = reg_tag_buf[95:64];
                5'd18: wb_dat_o = reg_tag_buf[63:32];
                5'd19: wb_dat_o = reg_tag_buf[31:0];
                default: wb_dat_o = 32'd0;
            endcase
        end
    end

endmodule