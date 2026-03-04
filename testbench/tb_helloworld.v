`timescale 1ns / 1ps

module tb_helloworld;

  // -------------------------------------------------------------------------
  // 1. Khai báo tham số (Parameters)
  // -------------------------------------------------------------------------
  parameter CLOCK_FREQUENCY = 50000000; // 50MHz
  parameter CLOCK_PERIOD    = 20;       // 20ns
  
  // Tên file HEX (Đảm bảo file này đã nằm trong thư mục Simulation)
  parameter MEMORY_FILENAME = "hello.hex"; 

  // -------------------------------------------------------------------------
  // 2. Khai báo tín hiệu (Signals)
  // -------------------------------------------------------------------------
  reg           clk_i;
  reg           rst_i;
  wire          uart_tx;
  
  wire [31:0]   gpio;
  wire          sclk;
  wire          pico;
  wire          cs;

  // -------------------------------------------------------------------------
  // 3. Tạo xung Clock
  // -------------------------------------------------------------------------
  initial begin
    clk_i = 0;
    forever begin
      #(CLOCK_PERIOD / 2); 
      clk_i = ~clk_i;      
    end
  end

  // -------------------------------------------------------------------------
  // 4. Tạo tín hiệu Reset
  // -------------------------------------------------------------------------
  initial begin
    rst_i = 1;       
    #100;            
    rst_i = 0;       
  end

  // -------------------------------------------------------------------------
  // 5. Gọi module MCU (DUT)
  // -------------------------------------------------------------------------
  mcu_top #(
    .MEMORY_SIZE(8192),                 
    .MEMORY_INIT_FILE(MEMORY_FILENAME), 
    .CLOCK_FREQUENCY(CLOCK_FREQUENCY)   
  ) mcu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .halt(1'b0),      
    .uart_rx(1'b1),   
    .uart_tx(uart_tx),
    .gpio(gpio),      
    .sclk(sclk),      
    .poci(1'b0),      
    .pico(pico),      
    .cs(cs)           
  );

  // =========================================================================
  // 6. UART DECODER - GIẢI MÃ TÍN HIỆU ĐỂ HIỆN CHỮ (Mới thêm vào)
  // =========================================================================
  
  reg [7:0] received_data; // Biến chứa ký tự đã giải mã
  
  // Thời gian 1 bit cho 9600 baud (1s / 9600 = ~104166 ns)
  // Code này giải mã cho đoạn đầu "FCE base..." chạy 9600 baud
  localparam BIT_PERIOD = 104166; 

  initial begin
      received_data = 0;
      forever begin
         // 1. Chờ cạnh xuống của Start Bit
         @(negedge uart_tx);
         
         // 2. Nhảy vào giữa bit đầu tiên (Start bit + 0.5 bit dữ liệu)
         #(BIT_PERIOD + (BIT_PERIOD / 2));
         
         // 3. Đọc 8 bit dữ liệu (LSB trước)
         received_data[0] = uart_tx; #(BIT_PERIOD);
         received_data[1] = uart_tx; #(BIT_PERIOD);
         received_data[2] = uart_tx; #(BIT_PERIOD);
         received_data[3] = uart_tx; #(BIT_PERIOD);
         received_data[4] = uart_tx; #(BIT_PERIOD);
         received_data[5] = uart_tx; #(BIT_PERIOD);
         received_data[6] = uart_tx; #(BIT_PERIOD);
         received_data[7] = uart_tx; 
         
         // In ký tự ra màn hình console (Transcript) để tiện theo dõi
         $write("%c", received_data);
      end
  end

  // -------------------------------------------------------------------------
  // 7. Điều khiển thời gian mô phỏng
  // -------------------------------------------------------------------------
  initial begin
    $display("Simulation Started. Running...");

    // Chạy đủ lâu để xem hết chuỗi ký tự
    #15000000; // Tăng lên 15ms cho chắc chắn thấy hết chữ
    
    $display("\nSimulation Finished.");
    $stop; 
  end

endmodule