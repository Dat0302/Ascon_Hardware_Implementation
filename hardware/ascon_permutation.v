module ascon_permutation (
    input  wire [63:0] x0_in, x1_in, x2_in, x3_in, x4_in,
    input  wire [3:0]  round_idx, // Index vòng: 0 đến 11
    output wire [63:0] x0_out, x1_out, x2_out, x3_out, x4_out
);

    // --- 1. Constant Addition (Cộng hằng số) ---
    // Chỉ x2 bị thay đổi bởi hằng số vòng.
    // Công thức Constant: High nibble = (15 - round), Low nibble = round
    wire [7:0] round_constant;
    assign round_constant = { (4'hf - round_idx), round_idx };
    
    wire [63:0] x2_c;
    assign x2_c = x2_in ^ {56'h0, round_constant};

    // --- 2. Substitution Layer (S-box) ---
    // Sử dụng chuỗi cổng logic tối ưu cho phần cứng (Bitslice implementation)
    wire [63:0] s0, s1, s2, s3, s4; // Biến tạm sau bước XOR đầu
    wire [63:0] t0, t1, t2, t3, t4; // Biến tạm sau bước Non-linear

    // Bước 2.1: XOR mix đầu vào
    assign s0 = x0_in ^ x4_in;
    assign s1 = x1_in;
    assign s2 = x2_c  ^ x1_in;
    assign s3 = x3_in;
    assign s4 = x4_in ^ x3_in;

    // Bước 2.2: Lớp phi tuyến (Non-linear layer - Chi substitution)
    // Công thức: x_i = x_i ^ ((~x_i+1) & x_i+2)
    assign t0 = s0 ^ (~s1 & s2);
    assign t1 = s1 ^ (~s2 & s3);
    assign t2 = s2 ^ (~s3 & s4);
    assign t3 = s3 ^ (~s4 & s0);
    assign t4 = s4 ^ (~s0 & s1);

    // Bước 2.3: XOR mix đầu ra
    wire [63:0] x0_s, x1_s, x2_s, x3_s, x4_s;
    assign x0_s = t0 ^ t4;
    assign x1_s = t1 ^ t0;
    assign x2_s = ~t2;      // Lưu ý: Có phép NOT ở x2
    assign x3_s = t3 ^ t2;
    assign x4_s = t4;

    // --- 3. Linear Diffusion Layer (Khuếch tán tuyến tính) ---
    // Sử dụng đúng các giá trị quay phải (Right Rotate) theo spec
    // Cú pháp Verilog {val[N-1:0], val[63:N]} là quay TRÁI.
    // Cú pháp Verilog {val[N:0], val[63:N+1]} là quay PHẢI (đúng cho Ascon)
    
    // x0: Rotate 19, 28
    assign x0_out = x0_s ^ {x0_s[18:0], x0_s[63:19]} ^ {x0_s[27:0], x0_s[63:28]};
    // x1: Rotate 61, 39
    assign x1_out = x1_s ^ {x1_s[60:0], x1_s[63:61]} ^ {x1_s[38:0], x1_s[63:39]};
    // x2: Rotate 1, 6
    assign x2_out = x2_s ^ {x2_s[0],  x2_s[63:1]}  ^ {x2_s[5:0],  x2_s[63:6]};
    // x3: Rotate 10, 17
    assign x3_out = x3_s ^ {x3_s[9:0], x3_s[63:10]} ^ {x3_s[16:0], x3_s[63:17]};
    // x4: Rotate 7, 41
    assign x4_out = x4_s ^ {x4_s[6:0], x4_s[63:7]}  ^ {x4_s[40:0], x4_s[63:41]};

endmodule