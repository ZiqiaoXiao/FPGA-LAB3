module MUST (
    input wire sys_clk,        // VGA时钟
    input wire sys_rst_n,      // 系统复位
    output reg hs,             // 行同步信号
    output reg vs,             // 场同步信号
    output reg [15:0] rgb      // RGB输出 [15:11]红, [10:5]绿, [4:0]蓝 (RGB565格式)
);

// VGA时序参数 (640x480@60Hz)
localparam H_DISPLAY = 640;
localparam H_FRONT   = 16;
localparam H_SYNC    = 96;
localparam H_BACK    = 48;
localparam H_TOTAL   = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;

localparam V_DISPLAY = 480;
localparam V_FRONT   = 10;
localparam V_SYNC    = 2;
localparam V_BACK    = 33;
localparam V_TOTAL   = V_DISPLAY + V_FRONT + V_SYNC + V_BACK;

reg vga_clk;
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        vga_clk <= 0;
    end else begin
        vga_clk <= ~vga_clk;
    end
end


// 计数器
reg [9:0] h_count;
reg [9:0] v_count;

// 像素坐标
wire [9:0] pix_x;
wire [9:0] pix_y;

assign pix_x = h_count;
assign pix_y = v_count;


parameter ORIG_CHAR_HEIGHT = 16;
parameter CHAR_HEIGHT = 80;    // 80像素
parameter TOTAL_WIDTH =300;
parameter TOTAL_HEIGHT = CHAR_HEIGHT;
parameter START_X = 200;
parameter START_Y = 200;

// 有效显示区域
wire display_area;
assign display_area = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);

// 字符ROM输出
wire [15:0] pix_data;

// 字符ROM实例
char_rom char_rom_inst (
    .vga_clk(vga_clk),
    .sys_rst_n(sys_rst_n),
    .pix_x(pix_x),
    .pix_y(pix_y),
    .pix_data(pix_data)
);


// 行计数器
always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        h_count <= 10'd0;
    end else begin
        if (h_count == H_TOTAL - 1) begin
            h_count <= 10'd0;
        end else begin
            h_count <= h_count + 10'd1;
        end
    end
end

// 场计数器
always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        v_count <= 10'd0;
    end else begin
        if (h_count == H_TOTAL - 1) begin
            if (v_count == V_TOTAL - 1) begin
                v_count <= 10'd0;
            end else begin
                v_count <= v_count + 10'd1;
            end
        end
    end
end

// 行同步信号
always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        hs <= 1'b1;
    end else begin
        if (h_count >= (H_DISPLAY + H_FRONT) && 
            h_count < (H_DISPLAY + H_FRONT + H_SYNC)) begin
            hs <= 1'b0;
        end else begin
            hs <= 1'b1;
        end
    end
end

// 场同步信号
always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        vs <= 1'b1;
    end else begin
        if (v_count >= (V_DISPLAY + V_FRONT) && 
            v_count < (V_DISPLAY + V_FRONT + V_SYNC)) begin
            vs <= 1'b0;
        end else begin
            vs <= 1'b1;
        end
    end
end

// RGB输出 - 16位版本 (RGB565格式)
always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        rgb <= 16'b00000_000000_00000;  // 黑色
    end else if (display_area) begin
        // 直接判断是否为白色
        if (pix_data == 16'hFFFF) begin
            rgb <= 16'b11111_111111_11111;  // 白色 (RGB565)
        end else begin
            rgb <= 16'b00000_000000_00000;  // 黑色 (RGB565)
        end
    end else begin
        rgb <= 16'b00000_000000_00000;      // 消隐区域显示黑色
    end
end

endmodule


module char_rom (
    input wire vga_clk,           // VGA时钟
    input wire sys_rst_n,         // 系统复位
    input wire [9:0] pix_x,       // 像素X坐标
    input wire [9:0] pix_y,       // 像素Y坐标
    output reg [15:0] pix_data    // 像素数据输出
);
// 参数定义
parameter BLACK = 16'h0000;
parameter WHITE = 16'hFFFF;

parameter H_VALID = 10'd640;
parameter V_VALID = 10'd480;

// 字符参数
parameter ORIG_CHAR_WIDTH = 16;
parameter ORIG_CHAR_HEIGHT = 16;
parameter SCALE_FACTOR = 5;
parameter CHAR_WIDTH = ORIG_CHAR_WIDTH * SCALE_FACTOR;      // 80像素
parameter CHAR_HEIGHT = ORIG_CHAR_HEIGHT * SCALE_FACTOR;    // 80像素
parameter CHAR_SPACING = 8 * SCALE_FACTOR;                  // 40像素间距
parameter NUM_CHARS = 4;

// 位置参数 - 修正总宽度计算
parameter TOTAL_WIDTH = NUM_CHARS * CHAR_WIDTH + (NUM_CHARS - 1) * CHAR_SPACING; // 4*80 + 3*40 = 440
parameter TOTAL_HEIGHT = CHAR_HEIGHT;
parameter START_X = 200;  // 调整起始位置确保不超出屏幕
parameter START_Y = 200;

// 字符数据保持不变...

// 字符数据 - 16x16像素的4个字符
reg [15:0] char_m [0:15]; // M字符
reg [15:0] char_u [0:15]; // U字符
reg [15:0] char_s [0:15]; // S字符
reg [15:0] char_t [0:15]; // T字符

// 初始化字符数据 - 修正位序
initial begin
    // M字符数据 (16x16) - 修正位序
    char_m[ 0] = 16'h0000; // 0000000000000000
    char_m[ 1] = 16'h0000; // 0000000000000000
    char_m[ 2] = 16'h0000; // 0000000000000000
    char_m[ 3] = 16'h0077; // 0000000001110111 (注意：ee00 -> 01110111)
    char_m[ 4] = 16'h0036; // 0000000000110110 (6c00 -> 00110110)
    char_m[ 5] = 16'h0036; // 0000000000110110
    char_m[ 6] = 16'h0036; // 0000000000110110
    char_m[ 7] = 16'h0036; // 0000000000110110
    char_m[ 8] = 16'h002A; // 0000000000101010 (5400 -> 00101010)
    char_m[ 9] = 16'h002A; // 0000000000101010
    char_m[10] = 16'h002A; // 0000000000101010
    char_m[11] = 16'h002A; // 0000000000101010
    char_m[12] = 16'h006B; // 0000000001101011 (d600 -> 01101011)
    char_m[13] = 16'h0000; // 0000000000000000
    char_m[14] = 16'h0000; // 0000000000000000
    char_m[15] = 16'h0000; // 0000000000000000

    // U字符数据 (16x16) - 修正位序
    char_u[ 0] = 16'h0000; // 0000000000000000
    char_u[ 1] = 16'h0000; // 0000000000000000
    char_u[ 2] = 16'h0000; // 0000000000000000
    char_u[ 3] = 16'h00E7; // 0000000011100111 (e700 -> 11100111)
    char_u[ 4] = 16'h0042; // 0000000001000010 (4200 -> 01000010)
    char_u[ 5] = 16'h0042; // 0000000001000010
    char_u[ 6] = 16'h0042; // 0000000001000010
    char_u[ 7] = 16'h0042; // 0000000001000010
    char_u[ 8] = 16'h0042; // 0000000001000010
    char_u[ 9] = 16'h0042; // 0000000001000010
    char_u[10] = 16'h0042; // 0000000001000010
    char_u[11] = 16'h0042; // 0000000001000010
    char_u[12] = 16'h003C; // 0000000000111100 (3c00 -> 00111100)
    char_u[13] = 16'h0000; // 0000000000000000
    char_u[14] = 16'h0000; // 0000000000000000
    char_u[15] = 16'h0000; // 0000000000000000

    // S字符数据 (16x16) - 修正位序
    char_s[ 0] = 16'h0000; // 0000000000000000
    char_s[ 1] = 16'h0000; // 0000000000000000
    char_s[ 2] = 16'h0000; // 0000000000000000
    char_s[ 3] = 16'h007C; // 0000000001111100 (3e00 -> 00111110 -> 01111100)
    char_s[ 4] = 16'h0042; // 0000000001000010 (4200 -> 01000010)
    char_s[ 5] = 16'h0042; // 0000000001000010
    char_s[ 6] = 16'h0020; // 0000000000000010 (4000 -> 01000000 -> 00000010)
    char_s[ 7] = 16'h0010; // 0000000000000100 (2000 -> 00100000 -> 00000100)
    char_s[ 8] = 16'h000C; // 0000000000011000 (1800 -> 00011000)
    char_s[ 9] = 16'h0002; // 0000000000100000 (0400 -> 00000100 -> 00100000)
    char_s[10] = 16'h0002; // 0000000001000000 (0200 -> 00000010 -> 01000000)
    char_s[11] = 16'h0042; // 0000000001000010 (4200 -> 01000010)
    char_s[12] = 16'h003E; // 0000000000111110 (7c00 -> 01111100 -> 00111110)
    char_s[13] = 16'h0000; // 0000000000000000
    char_s[14] = 16'h0000; // 0000000000000000
    char_s[15] = 16'h0000; // 0000000000000000

    // T字符数据 (16x16) - 修正位序
    char_t[ 0] = 16'h0000; // 0000000000000000
    char_t[ 1] = 16'h0000; // 0000000000000000
    char_t[ 2] = 16'h0000; // 0000000000000000
    char_t[ 3] = 16'h007F; // 0000000001111111 (fe00 -> 11111110 -> 01111111)
    char_t[ 4] = 16'h0049; // 0000000001001001 (9200 -> 10010010 -> 01001001)
    char_t[ 5] = 16'h0008; // 0000000000001000 (1000 -> 00010000 -> 00001000)
    char_t[ 6] = 16'h0008; // 0000000000001000
    char_t[ 7] = 16'h0008; // 0000000000001000
    char_t[ 8] = 16'h0008; // 0000000000001000
    char_t[ 9] = 16'h0008; // 0000000000001000
    char_t[10] = 16'h0008; // 0000000000001000
    char_t[11] = 16'h0008; // 0000000000001000
    char_t[12] = 16'h001C; // 0000000000011100 (3800 -> 00111000 -> 00011100)
    char_t[13] = 16'h0000; // 0000000000000000
    char_t[14] = 16'h0000; // 0000000000000000
    char_t[15] = 16'h0000; // 0000000000000000
end

// 字符显示区域
wire char_display_area;
assign char_display_area = (pix_x >= START_X) && 
                          (pix_x < START_X + TOTAL_WIDTH) && 
                          (pix_y >= START_Y) && 
                          (pix_y < START_Y + TOTAL_HEIGHT);

// 字符索引和像素位置
wire [1:0] char_index;
wire [6:0] char_pixel_x;
wire [6:0] char_pixel_y;
wire [3:0] orig_char_x;
wire [3:0] orig_char_y;
wire [15:0] current_char_line;
wire char_index_valid;  // 新增：字符索引有效性检查

// 计算当前显示的是哪个字符 (0-3)
assign char_index = (pix_x - START_X) / (CHAR_WIDTH + CHAR_SPACING);

// 字符索引有效性检查
assign char_index_valid = (char_index < NUM_CHARS);

// 计算字符内的放大像素坐标
assign char_pixel_x = (pix_x - START_X) - char_index * (CHAR_WIDTH + CHAR_SPACING);
assign char_pixel_y = (pix_y - START_Y);

// 计算对应的原始字符坐标
assign orig_char_x = char_pixel_x / SCALE_FACTOR;
assign orig_char_y = char_pixel_y / SCALE_FACTOR;

// 选择当前字符的对应行数据
assign current_char_line = 
    (char_index == 2'b00) ? char_m[orig_char_y] :
    (char_index == 2'b01) ? char_u[orig_char_y] :
    (char_index == 2'b10) ? char_s[orig_char_y] :
    (char_index == 2'b11) ? char_t[orig_char_y] : 16'h0000;  // 默认值

// 像素数据输出 - 修正边界检查
always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        pix_data <= BLACK;
    else if (char_display_area && char_index_valid && 
             char_pixel_x < CHAR_WIDTH && char_pixel_y < CHAR_HEIGHT) begin
        // 检查像素坐标在有效范围内
        if (current_char_line[15 - orig_char_x])
            pix_data <= WHITE;
        else
            pix_data <= BLACK;
    end else
        pix_data <= BLACK;
end
endmodule