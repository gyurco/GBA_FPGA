//============================================================================
//  GBA top-level for MiST
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module GBA_MiST
(
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
	input         UART_RX,
	output        UART_TX

);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

// remove this if the 2nd chip is actually used

`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 1;
assign SDRAM2_DQMH = 1;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif

`include "build_id.v"

assign LED  = ~ioctl_download;

parameter CONF_STR = {
	"GBA;;",
	"F1,GBA;",
	`SEP
	"P1,Video & Audio;",
	"P1O3,Blend,Off,On;",
	"P1O8,Sync core to video,On,Off;",
	//"P1O9A,Flickerblend,Off,Blend,30Hz;",
	//"P1OBC,2XResolution,Off,Background,Sprites,Both;",
	"P1OD,Spritelimit,Off,On;",
	"T0,Reset;",
	"V,v1.0.",`BUILD_DATE
};

wire        blend = status[3];
wire        sync_core = ~status[8];
wire  [1:0] hires = 0;//status[12:11];
wire        spritelimit = status[13];

////////////////////   CLOCKS   ///////////////////

wire pll_locked;
wire clk_sys, clk_vid;
assign SDRAM_CLK = clk_sys;

pll pll
(
`ifdef USE_CLOCK_50
	.inclk0(CLOCK_50),
`else
	.inclk0(CLOCK_27),
`endif
	.c0(clk_sys),
	.c1(clk_vid),
	.locked(pll_locked)
);

reg reset;
always @(posedge clk_sys) begin
	reset <= buttons[1] | status[0] | ioctl_download;
end

//////////////////   MiST I/O   ///////////////////
wire [31:0] joy_0;
wire [31:0] joy_1;
wire [31:0] joy_2;
wire [31:0] joy_3;
wire [31:0] joy_4;

wire [31:0] joystick_analog_0;
wire [31:0] joystick_analog_1;

wire  [1:0] buttons;
wire [63:0] status;
wire [63:0] RTC_time;
wire        ypbpr;
wire        scandoubler_disable;
wire        no_csync;

wire  [8:0] mouse_x;
wire  [8:0] mouse_y;
wire  [7:0] mouse_flags;  // YOvfl, XOvfl, dy8, dx8, 1, mbtn, rbtn, lbtn
wire        mouse_strobe;

wire        key_strobe;
wire        key_pressed;
wire        key_extended;
wire  [7:0] key_code;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_buff_rd;
wire  [1:0] img_mounted;
wire [31:0] img_size;

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

user_io #(.STRLEN($size(CONF_STR)>>3), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14) | (QSPI << 2))) user_io
(
	.clk_sys(clk_sys),
	.clk_sd(clk_sys),
	.SPI_SS_IO(CONF_DATA0),
	.SPI_CLK(SPI_SCK),
	.SPI_MOSI(SPI_DI),
	.SPI_MISO(SPI_DO),

	.conf_str(CONF_STR),

	.status(status),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
	.buttons(buttons),
	.rtc(RTC_time),
	.joystick_0(joy_0),
	.joystick_1(joy_1),
	.joystick_2(joy_2),
	.joystick_3(joy_3),
	.joystick_4(joy_4),

	.joystick_analog_0(joystick_analog_0),
	.joystick_analog_1(joystick_analog_1),

	.mouse_x(mouse_x),
	.mouse_y(mouse_y),
	.mouse_flags(mouse_flags),
	.mouse_strobe(mouse_strobe),

	.key_strobe(key_strobe),
	.key_code(key_code),
	.key_pressed(key_pressed),
	.key_extended(key_extended),

`ifdef USE_HDMI
	.i2c_start      (i2c_start      ),
	.i2c_read       (i2c_read       ),
	.i2c_addr       (i2c_addr       ),
	.i2c_subaddr    (i2c_subaddr    ),
	.i2c_dout       (i2c_dout       ),
	.i2c_din        (i2c_din        ),
	.i2c_ack        (i2c_ack        ),
	.i2c_end        (i2c_end        ),
`endif

	.sd_conf(1'b0),
	.sd_sdhc(1'b1),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_dout(sd_buff_dout),
	.sd_din(sd_buff_din),
	.sd_dout_strobe(sd_buff_wr),
	.sd_din_strobe(sd_buff_rd),
	.img_mounted(img_mounted),
	.img_size(img_size)
);

wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;

data_io #(.DOUT_16(1'b1), .USE_QSPI(QSPI)) data_io
(
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK),
	.SPI_DI(SPI_DI),
	.SPI_DO(SPI_DO),
	.SPI_SS2(SPI_SS2),
	.SPI_SS4(SPI_SS4),
`ifdef USE_QSPI
	.QSCK(QSCK),
	.QCSn(QCSn),
	.QDAT(QDAT),
`endif
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index)
);

wire cart_download = ioctl_download & (ioctl_index[5:0] == 6'd1);
wire bios_download = ioctl_download & ((ioctl_index[5:0] == 6'd0) && (ioctl_index[7:6] == 0)) || (ioctl_index[5:0] == 2);

reg [26:0] last_addr;
reg flash_1m;
reg ioctl_download_l;
reg sram_quirk = 0;            // game tries to use SRAM as emulation detection. This bit forces to pretent we have no SRAM
reg memory_remap_quirk = 0;    // game uses memory mirroring, e.g. access 4Mbyte but is only 1 Mbyte. 
reg gpio_quirk = 0;            // game exchanges some addresses to be GPIO lines for e.g. Solar or RTC
reg tilt_quirk = 0;            // game exchanges some addresses to be Tilt module
reg solar_quirk = 0;           // game has solar module
reg sprite_quirk = 0;          // game depends on using max sprite pixels per line, otherwise glitches appear

always @(posedge clk_sys) begin
	reg [31:0] cart_id;
	reg [63:0] str;

	ioctl_download_l <= ioctl_download;
	if (ioctl_download_l & ~ioctl_download & ioctl_index[5:0] == 6'd1) begin
		last_addr <= ioctl_addr;
	end
	if (~ioctl_download_l && cart_download) begin
		sram_quirk         <= 0;
		memory_remap_quirk <= 0;
		gpio_quirk         <= 0;
		tilt_quirk         <= 0;
		solar_quirk        <= 0;
		sprite_quirk       <= 0;
		flash_1m           <= 0;
	end

	if(ioctl_wr) begin
		if({str, ioctl_dout[7:0]} == "FLASH1M_V") flash_1m <= 1;
		if({str[55:0], ioctl_dout[7:0], ioctl_dout[15:8]} == "FLASH1M_V") flash_1m <= 1;
		str <= {str[47:0], ioctl_dout[7:0], ioctl_dout[15:8]};

		if(ioctl_addr[26:4] == 'hA) begin
			if(ioctl_addr[3:0] >= 12) cart_id[{4'd14 - ioctl_addr[3:0], 3'd0} +:16] <= {ioctl_dout[7:0],ioctl_dout[15:8]};
		end
		if(ioctl_addr == 'hB0) begin
			if(cart_id[31:8] == "AR8" ) begin sram_quirk <= 1;                                             end // Rocky US
			if(cart_id[31:8] == "ARO" ) begin sram_quirk <= 1;                                             end // Rocky EU
			if(cart_id[31:8] == "ALG" ) begin sram_quirk <= 1;                                             end // Dragon Ball Z - The Legacy of Goku
			if(cart_id[31:8] == "ALF" ) begin sram_quirk <= 1;                                             end // Dragon Ball Z - The Legacy of Goku II
			if(cart_id[31:8] == "BLF" ) begin sram_quirk <= 1;                                             end // 2 Games in 1 - Dragon Ball Z - The Legacy of Goku I & II
			if(cart_id[31:8] == "BDB" ) begin sram_quirk <= 1;                                             end // Dragon Ball Z - Taiketsu
			if(cart_id[31:8] == "BG3" ) begin sram_quirk <= 1;                                             end // Dragon Ball Z - Buu's Fury
			if(cart_id[31:8] == "BDV" ) begin sram_quirk <= 1;                                             end // Dragon Ball Z - Advanced Adventure
			if(cart_id[31:8] == "A2Y" ) begin sram_quirk <= 1;                                             end // Top Gun - Combat Zones
			if(cart_id[31:8] == "AI2" ) begin sram_quirk <= 1;                                             end // Iridion II
			if(cart_id[31:8] == "BPE" ) begin gpio_quirk <= 1;                                             end // POKEMON Emerald
			if(cart_id[31:8] == "AXV" ) begin gpio_quirk <= 1;                                             end // POKEMON Ruby
			if(cart_id[31:8] == "AXP" ) begin gpio_quirk <= 1;                                             end // POKEMON Sapphire
			if(cart_id[31:8] == "RZW" ) begin gpio_quirk <= 1;                                             end // WarioWare Twisted
			if(cart_id[31:8] == "BKA" ) begin gpio_quirk <= 1;                                             end // Sennen Kazoku
			if(cart_id[31:8] == "BR4" ) begin gpio_quirk <= 1;                                             end // Rockman EXE 4.5
			if(cart_id[31:8] == "V49" ) begin gpio_quirk <= 1;                                             end // Drill Dozer
			if(cart_id[31:8] == "2GB" ) begin gpio_quirk <= 1;                                             end // Goodboy Galaxy
			if(cart_id[31:8] == "BHG" ) begin                                           sprite_quirk <= 1; end // Gunstar Super Heroes
			if(cart_id[31:8] == "BGX" ) begin                                           sprite_quirk <= 1; end // Gunstar Super Heroes
			if(cart_id[31:8] == "KHP" ) begin tilt_quirk <= 1;                                             end // Koro Koro Puzzle JP
			if(cart_id[31:8] == "KYG" ) begin tilt_quirk <= 1;                                             end // Yoshi's Topsy-Turvy
			if(cart_id[31:8] == "U3I" ) begin gpio_quirk <= 1; solar_quirk <= 1;                           end // Boktai 1
			if(cart_id[31:8] == "U32" ) begin gpio_quirk <= 1; solar_quirk <= 1;                           end // Boktai 2
			if(cart_id[31:8] == "U33" ) begin gpio_quirk <= 1; solar_quirk <= 1;                           end // Boktai 3
			if(cart_id       == "FBME") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Bomberman
			if(cart_id       == "FADE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Castlevania
			if(cart_id       == "FDKE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Donkey Kong
			if(cart_id       == "FDME") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series DR. MARIO
			if(cart_id       == "FEBE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series EXCITEBIKE
			if(cart_id       == "FICE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series ICE CLIMBER
			if(cart_id       == "FMRE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series NES METROID
			if(cart_id       == "FP7E") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series PAC-MAN
			if(cart_id       == "FSME") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series SUPER MARIO Bros
			if(cart_id       == "FZLE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series The Legend of Zelda
			if(cart_id       == "FXVE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series XEVIOUS
			if(cart_id       == "FLBE") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Classic NES Series Zelda II - The Adventure of Link
			if(cart_id       == "FSRJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini - Dai-2-ji Super Robot Taisen (Japan) (Promo)
			if(cart_id       == "FGZJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini - Kidou Senshi Z Gundam - Hot Scramble (Japan) (Promo)
			if(cart_id       == "FSDJ") begin sram_quirk <= 1; memory_remap_quirk <= 1; sprite_quirk <= 1; end // Famicom Mini 30 - SD Gundam World - Gachapon Senshi Scramble Wars
			if(cart_id       == "FADJ") begin sram_quirk <= 1; memory_remap_quirk <= 1; sprite_quirk <= 1; end // Famicom Mini 29 - Akumajou Dracula
			if(cart_id       == "FTUJ") begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 28 - Famicom Tantei Club Part II - Ushiro ni Tatsu Shoujo - Zen, Kouhen
			if(cart_id       == "FTKJ") begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 27 - Famicom Tantei Club - Kieta Koukeisha - Zen, Kouhen
			if(cart_id       == "FFMJ") begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 26 - Famicom Mukashibanashi - Shin Onigashima - Zen, Kouhen
			if(cart_id       == "FLBJ") begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 25 - The Legend of Zelda 2 - Link no Bouken
			if(cart_id       == "FPTJ") begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 24 - Hikari Shinwa - Palthena no Kagami
			if(cart_id       == "FMRJ") begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 23 - Metroid
			if(cart_id       == "FNMJ") begin sram_quirk <= 1;                          sprite_quirk <= 1; end // Famicom Mini 22 - Nazo no Murasame Jou
			if(cart_id       == "FM2J") begin sram_quirk <= 1; memory_remap_quirk <= 1; sprite_quirk <= 1; end // Famicom Mini 21 - Super Mario Bros. 2
			if(cart_id       == "FGGJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 20 - Ganbare Goemon! - Karakuri Douchuu
			if(cart_id       == "FTWJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 19 - Twin Bee
			if(cart_id       == "FMKJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 18 - Makaimura
			if(cart_id       == "FTBJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 17 - Takahashi Meijin no Bouken-jima
			if(cart_id       == "FDDJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 16 - Dig Dug
			if(cart_id       == "FDMJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 15 - Dr. Mario
			if(cart_id       == "FWCJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 14 - Wrecking Crew
			if(cart_id       == "FVFJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 13 - Balloon Fight
			if(cart_id       == "FCLJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 12 - Clu Clu Land
			if(cart_id       == "FMBJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 11 - Mario Bros.
			if(cart_id       == "FSOJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 10 - Star Soldier
			if(cart_id       == "FBMJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 09 - Bomber Man
			if(cart_id       == "FMPJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 08 - Mappy
			if(cart_id       == "FXVJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 07 - Xevious
			if(cart_id       == "FPMJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 06 - Pac-Man
			if(cart_id       == "FZLJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 05 - Zelda no Densetsu 1 - The Hyrule Fantasy
			if(cart_id       == "FEBJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 04 - Excitebike
			if(cart_id       == "FICJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 03 - Ice Climber
			if(cart_id       == "FDKJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 02 - Donkey Kong
			if(cart_id       == "FSMJ") begin sram_quirk <= 1; memory_remap_quirk <= 1;                    end // Famicom Mini 01 - Super Mario Bros.
		end
	end
end

reg [11:0] bios_wraddr;
reg [31:0] bios_wrdata;
reg        bios_wr;
always @(posedge clk_sys) begin
	bios_wr <= 0;
	if(bios_download & ioctl_wr & ~status[28]) begin
		if(~ioctl_addr[1]) bios_wrdata[15:0] <= ioctl_dout;
		else begin
			bios_wrdata[31:16] <= ioctl_dout;
			bios_wraddr <= ioctl_addr[13:2];
			bios_wr <= 1;
		end
	end
end
////////////////////////////  SYSTEM  ///////////////////////////////////

wire save_eeprom, save_sram, save_flash, ss_loaded;

reg fast_forward, pause, cpu_turbo;
reg ff_latch;
/*
always @(posedge clk_sys) begin : ffwd
	reg last_ffw;
	reg ff_was_held;
	longint ff_count;

	last_ffw <= joy[10];

	if (joy[10])
		ff_count <= ff_count + 1;

	if (~last_ffw & joy[10]) begin
		ff_latch <= 0;
		ff_count <= 0;
	end

	if ((last_ffw & ~joy[10])) begin // 100mhz clock, 0.2 seconds
		ff_was_held <= 0;

		if (ff_count < 10000000 && ~ff_was_held) begin
			ff_was_held <= 1;
			ff_latch <= 1;
		end
	end

	fast_forward <= (joy[10] | ff_latch) & ~force_turbo;
	pause <= force_pause | (status[5] & OSD_STATUS & ~status[27]); // pause from "sync to core" or "pause in osd", but not if rewind capture is on
	cpu_turbo <= ((status[16] & ~fast_forward) | force_turbo) & ~pause;
end
*/
reg [79:0] time_dout = 41'd0;
wire [79:0] time_din;
assign time_din[42 + 32 +: 80 - (42 + 32)] = '0;

wire has_rtc;
wire cart_rumble;
reg RTC_load = 0;

reg [7:0] rumble_reg = 0;

always @(posedge clk_sys) begin
	rumble_reg <= (cart_rumble ? 8'd128 : 8'd0);
end

assign joy_rumble = {8'd0, rumble_reg};

wire [15:0] GBA_AUDIO_L;
wire [15:0] GBA_AUDIO_R;

gba_top
#(
   // assume: cart may have either flash or eeprom, not both! (need to verify)
	.Softmap_GBA_FLASH_ADDR  (0),                   // 131072 (8bit)  -- 128 Kbyte Data for GBA Flash
	.Softmap_GBA_EEPROM_ADDR (0),                   //   8192 (8bit)  --   8 Kbyte Data for GBA EEProm
	.Softmap_GBA_WRam_ADDR   (131072),              //  65536 (32bit) -- 256 Kbyte Data for GBA WRam Large
	.Softmap_GBA_Gamerom_ADDR(65536+131072),        //   32MB of ROM
	.Softmap_SaveState_ADDR  (58720256),            // 65536 (64bit) -- ~512kbyte Data for SaveState (separate memory)
	.Softmap_Rewind_ADDR     (33554432),            // 65536 qwords*64 -- 64*512 Kbyte Data for Savestates
	.turbosound('1)                                 // sound buffer to play sound in turbo mode without sound pitched up
)
gba
(
	.clk100(clk_sys),
	.GBA_on(~reset),  // switching from off to on = reset
	.GBA_lockspeed(~fast_forward),       // 1 = 100% speed, 0 = max speed
	.GBA_cputurbo(cpu_turbo),
	.GBA_flash_1m(flash_1m),          // 1 when string "FLASH1M_V" is anywhere in gamepak
	.CyclePrecalc(pause ? 16'd0 : 16'd100), // 100 seems to be ok to keep fullspeed for all games
	.Underclock(status[42:41]),
	.MaxPakAddr(last_addr[26:2]),     // max byte address that will contain data, required for buggy games that read behind their own memory, e.g. zelda minish cap
	.CyclesMissing(),                 // debug only for speed measurement, keep open
	.CyclesVsyncSpeed(),              // debug only for speed measurement, keep open
	.SramFlashEnable(~sram_quirk),
	.memory_remap(memory_remap_quirk),
	.increaseSSHeaderCount(!status[36]),
	.save_state(ss_save),
	.load_state(ss_load),
	.interframe_blend(2'b00),
	.maxpixels(spritelimit | sprite_quirk),
	.hdmode2x_bg(hires[0]),
	.hdmode2x_obj(hires[1]),
	.shade_mode(shadercolors),
	.specialmodule(gpio_quirk | status[40]),
	.solar_in(status[31:29]),
	.tilt(tilt_quirk),
	.rewind_on(/*status[27]*/),
	.rewind_active(1'b0/*status[27] & joy[11]*/),
	.savestate_number(ss_slot),

	.RTC_timestampNew(RTC_time[32]),
	.RTC_timestampIn(RTC_time[31:0]),
	.RTC_timestampSaved(time_dout[42 +: 32]),
	.RTC_savedtimeIn(time_dout[0 +: 42]),
	.RTC_saveLoaded(RTC_load),
	.RTC_timestampOut(time_din[42 +: 32]),
	.RTC_savedtimeOut(time_din[0 +: 42]),
	.RTC_inuse(has_rtc),

	.cheat_clear(gg_reset),
	.cheats_enabled(1'b0),
	.cheat_on(gg_valid),
	.cheat_in(gg_code),
	.cheats_active(gg_active),

	.sdram_read_ena(sdram_req),       // triggered once for read request
	.sdram_read_done(sdram_ack),      // must be triggered once when sdram_read_data is valid after last read
	.sdram_read_addr(sdram_addr),     // all addresses are DWORD addresses!
	.sdram_read_data(sdram_dout1),    // data from last request, valid when done = 1
	.sdram_second_dword(sdram_dout2), // second dword to be read for buffering/prefetch. Must be valid 1 cycle after done = 1

	.bus_out_Din(bus_din),            // data read from WRam Large, SRAM/Flash/EEPROM
	.bus_out_Dout(bus_dout),          // data written to WRam Large, SRAM/Flash/EEPROM
	.bus_out_Adr(bus_addr),           // all addresses are DWORD addresses!
	.bus_out_rnw(bus_rd),             // read = 1, write = 0
	.bus_out_ena(bus_req),            // one cycle high for each action
	.bus_out_done(bus_ack),           // should be one cycle high when write is done or read value is valid

	.SAVE_out_Din(ss_din),            // data read from savestate
	.SAVE_out_Dout(ss_dout),          // data written to savestate
	.SAVE_out_Adr(ss_addr),           // all addresses are DWORD addresses!
	.SAVE_out_rnw(ss_rnw),            // read = 1, write = 0
	.SAVE_out_ena(ss_req),            // one cycle high for each action
	.SAVE_out_be(ss_be),              
	.SAVE_out_done(ss_ack),           // should be one cycle high when write is done or read value is valid

	.save_eeprom(save_eeprom),
	.save_sram(save_sram),
	.save_flash(save_flash),
	.load_done(ss_loaded),

	.bios_wraddr(bios_wraddr),
	.bios_wrdata(bios_wrdata),
	.bios_wr(bios_wr),

	.KeyA(m_fireA),
	.KeyB(m_fireB),
	.KeySelect(m_fireC),
	.KeyStart(m_fireD),
	.KeyRight(m_right),
	.KeyLeft(m_left),
	.KeyUp(m_up),
	.KeyDown(m_down),
	.KeyR(m_fireE),
	.KeyL(m_fireF),
	.AnalogTiltX(joystick_analog_0[7:0]),
	.AnalogTiltY(joystick_analog_0[15:8]),
	.Rumble(cart_rumble),

	.pixel_out_addr(pixel_addr),      // integer range 0 to 38399;       -- address for framebuffer
	.pixel_out_data(pixel_data),      // RGB data for framebuffer
	.pixel_out_we(pixel_we),          // new pixel for framebuffer

	.largeimg_out_base(),
	.largeimg_out_addr(),
	.largeimg_out_data(),
	.largeimg_out_req(largeimg_out_req),
	.largeimg_out_done(largeimg_out_done),
	.largeimg_newframe(),
	.largeimg_singlebuf(),

	.sound_out_left(GBA_AUDIO_L),
	.sound_out_right(GBA_AUDIO_R)
);

wire [15:0] laudio = (fast_forward && status[19]) ? 16'd0 : GBA_AUDIO_L;
wire [15:0] raudio = (fast_forward && status[19]) ? 16'd0 : GBA_AUDIO_R;

///////////////////////////// MEMORY ////////////////////////////////////
wire largeimg_out_req;
reg largeimg_out_done;

always @(posedge clk_sys) begin
	if (reset)
		largeimg_out_done <= 1;
	else
		largeimg_out_done <= largeimg_out_req;
end

localparam ROM_START = (65536+131072)*4;

wire [25:2] sdram_addr;
wire [31:0] sdram_dout1;
wire [31:0] sdram_dout2;
wire        sdram_ack;
wire        sdram_req;

wire [25:2] bus_addr;
wire [31:0] bus_din;
wire [31:0] bus_dout;
wire        bus_ack;
wire        bus_rd, bus_req;

reg  [31:0] cart_wr_data;
reg         cart_wr;
reg  [26:2] cart_wr_addr;
always @(posedge clk_sys) begin
	cart_wr <= 0;
	if (ioctl_wr) begin
		if (!ioctl_addr[1]) 
			cart_wr_data[15:0] <= ioctl_dout;
		else begin
			cart_wr_data[31:16] <= ioctl_dout;
			cart_wr <= 1;
			cart_wr_addr <= ioctl_addr[26:2];
		end
	end
end

sdram sdram
(
	.*,
	.SDRAM_CLK(),
	.init(~pll_locked),
	.clk(clk_sys),

	.ch1_addr(cart_download ? {ROM_START[26:2] + cart_wr_addr, 1'b0} : {sdram_addr, 1'b0}),
	.ch1_din(cart_wr_data),
	.ch1_dout({sdram_dout2, sdram_dout1}),
	.ch1_req(cart_download ? cart_wr : sdram_req),
	.ch1_rnw(~cart_download),
	.ch1_ready(sdram_ack),

	.ch2_addr({bus_addr, 1'b0}),
	.ch2_din(bus_din),
	.ch2_dout(bus_dout),
	.ch2_req(~cart_download & bus_req),
	.ch2_rnw(bus_rd),
	.ch2_ready(bus_ack),

	.ch3_addr({sd_lba[7:0],bram_addr}),
	.ch3_din(bram_dout),
	.ch3_dout(bram_din),
	.ch3_req(bram_req),
	.ch3_rnw(~bk_loading || extra_data_addr),
	.ch3_ready(bram_ack)
);
//////////////////   VIDEO   //////////////////
wire [15:0] pixel_addr;
wire [17:0] pixel_data;
wire        pixel_we;

reg vsync;
always @(posedge clk_sys) begin
	reg [7:0] sync;

	sync <= sync << 1;
	if(pixel_we && pixel_addr == 0) sync <= 1;

	vsync <= |sync;
end

reg [17:0] vram[38400];
always @(posedge clk_sys) if(pixel_we) vram[pixel_addr] <= pixel_data;
always @(posedge clk_vid) rgb <= vram[px_addr];

wire [15:0] px_addr;
reg  [17:0] rgb;

reg hs, vs, hbl, vbl, ce_pix;
reg [5:0] r,g,b;
reg hold_reset, force_pause;
reg [13:0] force_pause_cnt;

reg ce_pix_req;
always @(posedge clk_vid) begin
	localparam V_START = 62;

	reg [8:0] x,y;
	reg [2:0] div;
	reg old_vsync;

	div <= div + 1'd1;

	ce_pix <= 0;
	ce_pix_req <= 0;
	if(!div) begin
		ce_pix <= 1;

		{r,g,b} <= rgb;

		if(x == 240) hbl <= 1;
		if(x == 000) hbl <= 0;

		if(x == 293) begin
			hs <= 1;

			if(y == 1)   vs <= 1;
			if(y == 4)   vs <= 0;
		end

		if(x == 293+32)    hs  <= 0;

		if(y == V_START)     vbl <= 0;
		if(y >= V_START+160) vbl <= 1;
	end

	if(ce_pix) begin
		ce_pix_req <= 1;
		if(vbl) px_addr <= 0;
		else if(!hbl) px_addr <= px_addr + 1'd1;

		x <= x + 1'd1;
		if(x == 398) begin
			x <= 0;
			if (~&y) y <= y + 1'd1;
			if (sync_core && y >= 263) y <= 0;

			if (y == V_START-1) begin
				// Pause the core for 22 Gameboy lines to avoid reading & writing overlap (tearing)
				force_pause <= (sync_core && ~fast_forward && pixel_addr < (240*22));
				force_pause_cnt <= 14'd10164; // 22* 264/228 *399
			end
		end

		if (force_pause) begin
			if (force_pause_cnt > 0)
				force_pause_cnt <= force_pause_cnt - 1'b1;
			else
				force_pause <= 0;
		end

	end

	old_vsync <= vsync;
	if(~old_vsync & vsync) begin
		if(~sync_core & vbl) begin
			x <= 0;
			y <= 0;
			vs <= 0;
			hs <= 0;
		end
	end

	// Avoid lost sync by reset, but force clearing reset at initial core load
	if (x == 0 && (y == 0 || y == 511))
		hold_reset <= 1'b0;
	else if (reset & sync_core)
		hold_reset <= 1'b1;

end

mist_video #(.SD_HCNT_WIDTH(10), .COLOR_DEPTH(6), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD), .OSD_AUTO_CE(1'b0)) mist_video
(
	.clk_sys(clk_vid),
	.scanlines(2'd0),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
	.rotate(2'b00),
	.blend(blend),
	.ce_divider(3'd0),
	.SPI_DI(SPI_DI),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.HSync(~hs),
	.VSync(~vs),
	.HBlank(hbl),
	.VBlank(vbl),
	.R(r),
	.G(g),
	.B(b),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B)
);

////////////////////////////  HDMI  ///////////////////////////////////

`ifdef USE_HDMI
i2c_master #(100_690_000) i2c_master (
	.CLK         (clk_sys),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout),
	.I2C_RDATA   (i2c_din),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

mist_video #(.SD_HCNT_WIDTH(10), .COLOR_DEPTH(6), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(8), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1'b1),  .OSD_AUTO_CE(1'b0)) hdmi_video
(
	.clk_sys(clk_vid),
	.scanlines(2'd0),
	.scandoubler_disable(1'b0),
	.ypbpr(1'b0),
	.no_csync(1'b1),
	.rotate(2'b00),
	.blend(blend),
	.ce_divider(3'd0),
	.SPI_DI(SPI_DI),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.HSync(~hs),
	.VSync(~vs),
	.HBlank(hbl),
	.VBlank(vbl),
	.R(r),
	.G(g),
	.B(b),
	.VGA_HS(HDMI_HS),
	.VGA_VS(HDMI_VS),
	.VGA_R(HDMI_R),
	.VGA_G(HDMI_G),
	.VGA_B(HDMI_B),
	.VGA_DE(HDMI_DE)
);

assign HDMI_PCLK = clk_vid;
`endif

//////////////////   AUDIO   //////////////////

hybrid_pwm_sd_2ndorder dac
(
	.clk(clk_vid),
	.reset_n(1'b1),
	.d_l({~laudio[15], laudio[14:0]}),
	.q_l(AUDIO_L),
	.d_r({~raudio[15], laudio[14:0]}),
	.q_r(AUDIO_R)
);

`ifdef I2S_AUDIO
i2s i2s
(
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(32'd100_690_000),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan({laudio}),
	.right_chan({raudio})
);
`endif

`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_sys) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_sys),
	.rst_i(1'b0),
	.clk_rate_i(32'd100_690_000),
	.spdif_o(SPDIF),
	.sample_i({raudio, laudio})
);
`endif

////////////////////////////  INPUT  ///////////////////////////////////
wire m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
wire m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;

arcade_inputs #(.START1(7)) inputs (
	.clk         ( clk_sys     ),
	.key_strobe  ( key_strobe  ),
	.key_pressed ( key_pressed ),
	.key_code    ( key_code    ),
	.joystick_0  ( joy_0       ),
	.joystick_1  ( joy_1       ),
	.rotate      ( 2'b00       ),
	.orientation ( 2'b00       ),
	.joyswap     ( 1'b0        ),
	.oneplayer   ( 1'b1        ),
	.controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
	.player1     ( {m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right} ),
	.player2     ( {m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2} )
);

endmodule
