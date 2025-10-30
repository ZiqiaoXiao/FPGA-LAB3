`timescale 1ns/1ps

module tb_MUST;

// 测试平台信号
reg vga_clk;
reg sys_rst_n;
wire hs;
wire vs;
wire [3:0] red;
wire [3:0] green;
wire [3:0] blue;

// 调试信号
wire [15:0] pix_data;
assign pix_data = uut.char_rom_inst.pix_data;

// PPM文件保存相关
integer ppm_file;
integer x, y;
reg [7:0] frame_buffer [0:479][0:639][0:2];
reg capture_frame;
integer frame_saved;
integer frame_count = 0;

// 实例化被测模块
MUST uut (
    .vga_clk(vga_clk),
    .sys_rst_n(sys_rst_n),
    .hs(hs),
    .vs(vs),
    .red(red),
    .green(green),
    .blue(blue)
);

// 时钟生成 - 50MHz (20ns周期)
always #10 vga_clk = ~vga_clk;

// 坐标跟踪
reg [9:0] current_x = 0, current_y = 0;

always @(posedge vga_clk) begin
    if (sys_rst_n) begin
        if (current_x < 639)
            current_x <= current_x + 1;
        else begin
            current_x <= 0;
            if (current_y < 479)
                current_y <= current_y + 1;
            else
                current_y <= 0;
        end
    end else begin
        current_x <= 0;
        current_y <= 0;
    end
end

// 帧捕获逻辑
reg vs_prev = 1;
always @(posedge vga_clk) begin
    if (sys_rst_n) begin
        vs_prev <= vs;
        if (!vs_prev && vs) begin // VSync上升沿
            frame_count <= frame_count + 1;
            $display("Frame %0d completed at time %0t", frame_count, $time);
            
            if (frame_count == 2 && !frame_saved) begin
                capture_frame <= 1;
                $display("Starting frame capture for PPM");
            end
        end
        
        if (capture_frame && current_x == 639 && current_y == 479) begin
            capture_frame <= 0;
            save_ppm();
        end
    end
end

// 帧缓冲区写入
always @(posedge vga_clk) begin
    if (sys_rst_n && capture_frame) begin
        if (current_x < 640 && current_y < 480) begin
            frame_buffer[current_y][current_x][0] <= {red, red}; // R
            frame_buffer[current_y][current_x][1] <= {green, green}; // G
            frame_buffer[current_y][current_x][2] <= {blue, blue}; // B
        end
    end
end

// 保存PPM文件任务
task save_ppm;
    integer i, j, k;
    begin
        ppm_file = $fopen("vga_output.ppm", "wb");
        if (!ppm_file) begin
            $display("ERROR: Could not open PPM file");
            $finish;
        end
        
        // 写入PPM头
        $fwrite(ppm_file, "P6\n640 480\n255\n");
        $display("Writing PPM data...");
        
        // 写入像素数据
        for (i = 0; i < 480; i = i + 1) begin
            for (j = 0; j < 640; j = j + 1) begin
                for (k = 0; k < 3; k = k + 1) begin
                    $fwrite(ppm_file, "%c", frame_buffer[i][j][k]);
                end
            end
            if (i % 60 == 0) 
                $display("Progress: %0d/480 lines written", i);
        end
        
        $fclose(ppm_file);
        frame_saved <= 1;
        $display("PPM file 'vga_output.ppm' saved successfully!");
        $display("File should show white 'MUST' characters on black background");
    end
endtask

// 主测试流程
initial begin
    vga_clk = 0;
    sys_rst_n = 0;
    capture_frame = 0;
    frame_saved = 0;
    
    // 初始化帧缓冲区为黑色
    for (y = 0; y < 480; y = y + 1) begin
        for (x = 0; x < 640; x = x + 1) begin
            frame_buffer[y][x][0] = 8'h00;
            frame_buffer[y][x][1] = 8'h00;
            frame_buffer[y][x][2] = 8'h00;
        end
    end
    
    $dumpfile("MUST.vcd");
    $dumpvars(0, tb_MUST);
    
    $display("=== MUST VGA Display Simulation Started ===");
    
    // 复位
    #100;
    sys_rst_n = 1;
    $display("Reset released at time %0t", $time);
    
    // 等待足够多的帧
    #50000000; // 50ms，大约3帧
    
    if (!frame_saved) begin
        $display("Manual PPM save triggered");
        save_ppm();
    end
    
    #1000000;
    $display("=== MUST Simulation Completed ===");
    $finish;
end

// 监视关键信号
always @(posedge vga_clk) begin
    if (sys_rst_n && current_x == 300 && current_y == 240) begin
        $display("At screen center: pix_data = %h", pix_data);
    end
end

endmodule