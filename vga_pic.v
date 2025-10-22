module vga_pic(
input wire vga_clk , //VGA working clock, 25MHz
input wire sys_rst_n , //Reset signal. Low level is effective
input wire [9:0] pix_x , //X coordinate of current pixel
input wire [9:0] pix_y , //Y coordinate of current pixel

output reg [15:0] pix_data //Color information

);

reg [127:0] char [31:0];

parameter BLACK = 16'h0000,
 		  WHITE = 16'hFFFF;

parameter H_VALID = 10'd640 ,
 		  V_VALID = 10'd480 ;

parameter CHAR_H_S = 10'd256 ,
		  CHAR_V_S = 10'd32;

parameter CHAR_H = 10'd192,
		  CHAR_V = 10'd224;


			

// 在 vga_pic.v 的 always 块中替换 char 数组的初始化
always @(posedge vga_clk) begin
    char[ 0] <= 128'h00000000000000000000000000000000;
    char[ 1] <= 128'h00000000000000000000000000000000;
    char[ 2] <= 128'h00000000000000000000000000000000;
    char[ 3] <= 128'h00000000000000000000000000000000;
    char[ 4] <= 128'h00000000000000000000000000000000;
    char[ 5] <= 128'h00000000000000000000000000000000;
    char[ 6] <= 128'h0000000000000000f81f0000fe3f0000;
    char[ 7] <= 128'h1ffc00007ffe0000783e00007c1e0000;
    char[ 8] <= 128'h3efc00007bde0000783e0000780c0000;
    char[ 9] <= 128'h383c000073ce0000783e0000780c0000;
    char[10] <= 128'h701c0000e3c600007c3e0000780c0000;
    char[11] <= 128'h701c0000e3c700007c7e0000780c0000;
    char[12] <= 128'h700c000003c000007c7e0000780c0000;
    char[13] <= 128'h7800000003c000007c7e0000780c0000;
    char[14] <= 128'h7c00000003c000007e7e0000780c0000;
    char[15] <= 128'h3f00000003c000007e7e0000780c0000;
    char[16] <= 128'h3fc0000003c000007efe0000780c0000;
    char[17] <= 128'h0ff0000003c000006efe0000780c0000;
    char[18] <= 128'h03f8000003c000006efe0000780c0000;
    char[19] <= 128'h00fc000003c000006fde0000780c0000;
    char[20] <= 128'h003c000003c000006fde0000780c0000;
    char[21] <= 128'h001e000003c000006fde0000780c0000;
    char[22] <= 128'h601e000003c0000067de0000780c0000;
    char[23] <= 128'h600e000003c00000679e0000380c0000;
    char[24] <= 128'h701e000003c00000679e0000381c0000;
    char[25] <= 128'h701e000003c00000679e00003c3c0000;
    char[26] <= 128'h783c000003c00000739e00001ff80000;
    char[27] <= 128'h7ff8000003c00000fb7f00000ff00000;
    char[28] <= 128'h7ff000000ff000000000000000000000;
    char[29] <= 128'h00000000000000000000000000000000;
    char[30] <= 128'h00000000000000000000000000000000;
    char[31] <= 128'h00000000000000000000000000000000;
end

always@(posedge vga_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        pix_data <= 16'd0;
    else if ((pix_x >= 192) && (pix_x < 448) &&  // 192+256=448
             (pix_y >= 224) && (pix_y < 256))    // 224+32=256
        pix_data <= WHITE;  // 先显示白色矩形测试
    else
        pix_data <= BLACK;
end

 endmodule
