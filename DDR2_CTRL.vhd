----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- 
-- Create Date:    14:09:12 09/15/2013 
-- Module Name:    DDR2_CTRL - Behavioral 
-- Description:    Simple SDRAM controller for a Micron 48LC16M16A2-7E
--                 or Micron 48LC4M16A2-7E @ 100MHz      
-- Revision: 
-- Revision 0.1 - Initial version
-- Revision 0.2 - Removed second clock signal that isn't needed.
-- Revision 0.3 - Added back-to-back reads and writes.
-- Revision 0.4 - Allow refeshes to be delayed till next PRECHARGE is issued,
--                Unless they get really, really delayed. If a delay occurs multiple
--                refreshes might get pushed out, but it will have avioded about 
--                50% of the refresh overhead
-- Revision 0.5 - Add more paramaters to the design, allowing it to work for both the 
--                Papilio Pro and Logi-Pi
-- Revision 0.6 - Fixed bugs in back-to-back reads (thanks Scotty!)
--
-- Worst case performance (single accesses to different rows or banks) is: 
-- Writes 16 cycles = 6,250,000 writes/sec = 25.0MB/s (excluding refresh overhead)
-- Reads  17 cycles = 5,882,352 reads/sec  = 23.5MB/s (excluding refresh overhead)
--
-- For 1:1 mixed reads and writes into the same row it is around 88MB/s 
-- For reads or wries to the same it is can be as high as 184MB/s 
--
--
-- Modified by Julian Loiacono, Aug 2017
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;
use IEEE.NUMERIC_STD.ALL;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

Library work;
use work.memory_word_type.all;


entity DDR2_CTRL is
    Port (
        -- clocks 
       clk100        : in  STD_LOGIC;
       clk200        : in  STD_LOGIC;
       reset         : in  STD_LOGIC;
       
       -- SDRAM signals
       FROM_RAMF_ALMOSTEMPTY : out std_logic;
       SDRAM_CKE     : out   STD_LOGIC := '0';
       SDRAM_CLK_P   : out   STD_LOGIC;
       SDRAM_CLK_N   : out   STD_LOGIC;
       SDRAM_CS      : out   STD_LOGIC := '0';
       SDRAM_RAS     : out   STD_LOGIC := '0';
       SDRAM_CAS     : out   STD_LOGIC := '0';
       SDRAM_WE      : out   STD_LOGIC := '0';
       SDRAM_DQS_P   : inout STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
       SDRAM_DQS_N   : inout STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
       SDRAM_DQM     : out   STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
       SDRAM_ADDR    : out   STD_LOGIC_VECTOR(sdram_rowcount-1 downto 0) := (others=>'0');
       SDRAM_BA      : out   STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
       SDRAM_DATA    : inout STD_LOGIC_VECTOR(sdramWidth-1 downto 0) := (others=>'0');
       
       -- external fifo access
       FROM_RAMF_DO   : out std_logic_vector (sdramWidth-1 downto 0);
       FROM_RAMF_RDEN : in std_logic;
       TO_RAMF_DI     : in std_logic_vector (sdramWidth-1 downto 0);
       TO_RAMF_WRandTOG   : in STD_LOGIC := '0';
       PARAMF_WREN    : in STD_LOGIC := '0';
       PARAMF_DI      : in std_logic_vector (RAM_WIDTH18-1 downto 0) := (others=>'0');
       
       initRam100      : in std_logic;
       ram_rst100   : in std_logic);
end DDR2_CTRL;

architecture Behavioral of DDR2_CTRL is 
    signal SDRAM_DATA_toSDRAM_prebuf    : STD_LOGIC_VECTOR(sdramWidth-1 downto 0) := (others=>'0');
    signal SDRAM_DATA_fromSDRAM_prebuf  : STD_LOGIC_VECTOR(sdramWidth-1 downto 0) := (others=>'0');
    signal SDRAM_TRISTATE_EN     : std_logic := '1';
    type doubleFifoCount is array (0 to 1) of std_logic_vector(9 downto 0);

    signal SDRAM_DQS_in : STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
    signal SDRAM_DQS_out : STD_LOGIC_VECTOR( 1 downto 0) := (others=>'0');
    signal SDRAM_DQS_tri : STD_LOGIC := '1';

    -- input and output fifo signals
    -- from sdram signals
    signal FROM_RAMF_ALMOSTFULL  : std_logic;
    signal FROM_RAMF_WREN        : STD_LOGIC := '0';
    signal FROM_RAMF_EMPTY       : STD_LOGIC := '0';
    signal FROM_RAMF_DI          : std_logic_vector (sdramWidth-1 downto 0);
    signal Z01_FROM_RAMF_DI      : doubleSDRAMdata;
    signal FROM_RAMF_CMDI        : std_logic_vector (1 downto 0) := (others=>'0');
    signal FROM_RAMF_FULL        : std_logic;
    signal FROM_RAMF_RDCOUNT     : std_logic_vector (9 downto 0) := (others=>'0');
    signal FROM_RAMF_RDERR       : std_logic;
    signal FROM_RAMF_WRCOUNT     : std_logic_vector (9 downto 0) := (others=>'0');
    signal FROM_RAMF_WRERR       : std_logic;
    
    -- to sdram signals
    signal TO_RAMF_ALMOSTFULL  : std_logic_vector (1 downto 0);  
    signal TO_RAMF_DO          : doubleSDRAMdata := (others=>(others=>'0'));
    signal Z01_TO_RAMF_DO      : doubleSDRAMdata := (others=>(others=>'0'));
    signal TO_RAMF_ALMOSTEMPTY : std_logic_vector (1 downto 0);
    signal TO_RAMF_EMPTY       : std_logic_vector (1 downto 0);
    signal TO_RAMF_FULL        : std_logic_vector (1 downto 0);
    signal TO_RAMF_RDCOUNT     : doubleFifoCount := (others=>(others=>'0'));
    signal TO_RAMF_RDERR       : std_logic_vector (1 downto 0);
    signal TO_RAMF_WRCOUNT     : doubleFifoCount := (others=>(others=>'0'));
    signal TO_RAMF_WRERR       : std_logic_vector (1 downto 0);
    signal TO_RAMF_WREN        : std_logic_vector(1 downto 0) := "00";
    signal TO_RAMF_RDEN        : std_logic := '0';
    
    -- param signals
    signal PARAMF_ALMOSTFULL  : STD_LOGIC;  
    signal PARAMF_DO          : std_logic_vector (RAM_WIDTH18-1 downto 0);
    signal PARAMF_ALMOSTEMPTY : std_logic;
    signal PARAMF_EMPTY       : std_logic;
    signal PARAMF_FULL        : std_logic;
    signal PARAMF_RDCOUNT     : std_logic_vector (9 downto 0);
    signal PARAMF_RDERR       : std_logic;
    signal PARAMF_WRCOUNT     : std_logic_vector (9 downto 0);
    signal PARAMF_WRERR       : std_logic;
    signal PARAMF_RDEN        : std_logic := '0';
    signal PARAMF_RDEN_Z01    : std_logic := '0';
        
   -- From page 37 of MT48LC16M16A2 datasheet
   -- Name (Function)       CS# RAS# CAS# WE# DQM  Addr    Data
   -- COMMAND INHIBIT (NOP)  H   X    X    X   X     X       X
   -- NO OPERATION (NOP)     L   H    H    H   X     X       X
   -- ACTIVE                 L   L    H    H   X  Bank/row   X
   -- READ                   L   H    L    H  L/H Bank/col   X
   -- WRITE                  L   H    L    L  L/H Bank/col Valid
   -- BURST TERMINATE        L   H    H    L   X     X     Active
   -- PRECHARGE              L   L    H    L   X   Code      X
   -- AUTO REFRESH           L   L    L    H   X     X       X 
   -- LOAD MODE REGISTER     L   L    L    L   X  Op-code    X 
   -- Write enable           X   X    X    X   L     X     Active
   -- Write inhibit          X   X    X    X   H     X     High-Z

   -- Here are the commands mapped to constants   
   constant CMD_UNSELECTED    : std_logic_vector(3 downto 0) := "1000";
   constant CMD_NOP           : std_logic_vector(3 downto 0) := "0111";
   constant CMD_ACTIVE        : std_logic_vector(3 downto 0) := "0011";
   constant CMD_READ          : std_logic_vector(3 downto 0) := "0101";
   constant CMD_WRITE         : std_logic_vector(3 downto 0) := "0100";
   constant CMD_TERMINATE     : std_logic_vector(3 downto 0) := "0110";
   constant CMD_PRECHARGE     : std_logic_vector(3 downto 0) := "0010";
   constant CMD_REFRESH       : std_logic_vector(3 downto 0) := "0001";
   constant CMD_LOAD_MODE_REG : std_logic_vector(3 downto 0) := "0000";

   constant CL                : integer := 3;
   constant AL                : integer := 2;
   constant RL                : integer := CL + AL - 1;
   constant BL                : integer := 4;
   constant BURST_MAX         : integer := 8;
   constant BURST_PATTERN_WR  : std_logic_vector(BURST_MAX-1 downto 0)  := "00000011";
   constant BURST_PATTERN_RD  : std_logic_vector(BURST_MAX-1 downto 0)  := "00000001";
   signal wr_burst_w_delay    : std_logic_vector(RL + BURST_MAX -1 downto 0)  := (others=>'0');
  
   signal data_ready_delay    : std_logic_vector((BURST_MAX+AL+CL)*2-1 downto 0) := (others=>'0');   
--    constant BL      : integer := 4;
--    constant BURST_PATTERN_WR     : std_logic_vector(7 downto 0)  := "00001111";
  
   signal iob_command     : std_logic_vector( 3 downto 0) := CMD_NOP;
   
   attribute IOB: string;
   attribute IOB of SDRAM_CKE  : signal is "true";
   attribute IOB of SDRAM_CS      : signal is "true";
   attribute IOB of SDRAM_RAS     : signal is "true";
   attribute IOB of SDRAM_CAS     : signal is "true";
   attribute IOB of SDRAM_WE      : signal is "true";
   attribute IOB of SDRAM_DQM     : signal is "true";
   attribute IOB of SDRAM_ADDR    : signal is "true";
   attribute IOB of SDRAM_BA      : signal is "true";
   
   type sdram_fsm_state is (
        s_init1, s_init2, s_init3, s_init4, s_init5, s_init6, s_init7, s_init8, 
        s_init9, s_init10, s_init11, s_init12, s_init13, s_init14, s_init15, 
        s_idle_in_wait,
        s_idle,
        s_open_in_2, s_open_in_1,
        s_write_1, s_write_wait, s_write_3, s_write_4,
        s_read_1,  s_read_2,
        s_precharge
        );

    signal sdram_state     : sdram_fsm_state := s_init1;
    signal sdram_laststate : sdram_fsm_state := s_init1;
    attribute FSM_ENCODING : string;
    attribute FSM_ENCODING of sdram_state : signal is "ONE-HOT";
    
    -- dual purpose counter, it counts up during the startup phase, then is used to trigger refreshes.
    constant startup_refresh_max : unsigned(13 downto 0) := (others => '1');  
    signal   refresh_count       : unsigned(13 downto 0) := (others => '0');
    
    -- logic to decide when to refresh
    signal pending_refresh : std_logic := '0';
    signal forcing_refresh : std_logic := '0';
    
    -- The incoming address is split into these three values
    signal addr_bank_wr     : std_logic_vector(log2(BANKCOUNT) -1 downto 0) := (others => '0');
    signal addr_row_wr      : std_logic_vector(sdram_rowcount-1 downto 0) := (others => '0');
    signal addr_col_wr      : std_logic_vector(sdram_colcount-1 downto 0) := (others => '0');
    signal addr_bank_rd     : std_logic_vector(log2(BANKCOUNT) -1 downto 0) := (others => '0');
    signal addr_row_rd      : std_logic_vector(sdram_rowcount-1 downto 0) := (others => '0');
    signal addr_col_rd_without_taps      : std_logic_vector(sdram_colcount-totaltapcountlog2-1 downto 0) := (others => '0');
    signal isRead           : std_logic := '0';
    constant prefresh_cmd  : natural := 10;
    
    -- BANK address chooses:
    constant MRS     : std_logic_vector(1  downto 0) := "00"; --PD    WR   DLLRST  TM   CASLATE BTYPE BLENGTH(4)
    constant MRS_SET : std_logic_vector(12 downto 0) :=        "0" & "010" & "1" & "0" & "011" & "0" & "010";
    constant EMR1    : std_logic_vector(1  downto 0) := "01";--Qoff       DQS#  OCDPROG   RtM  LATENCY  RTL   DIC   DLL
    constant EMR1_SET_ENTER: std_logic_vector(12 downto 0) :=  "0" & "0" & "1" & "111"  & "0" & "010" & "1" & "1" & "0";
                                                            --Qoff        DQS#  OCDPROG   RtM  LATENCY  RTL   DIC   DLL
    constant EMR1_SET_EXIT : std_logic_vector(12 downto 0) :=  "0" & "0" & "1" & "000"  & "0" & "010" & "1" & "1" & "0";
    constant EMR2    : std_logic_vector(1  downto 0) := "10";
    constant EMR2_SET: std_logic_vector(12 downto 0) := (others => '0');
    constant EMR3    : std_logic_vector(1  downto 0) := "11";
    constant EMR3_SET: std_logic_vector(12 downto 0) := (others => '0');
    
    constant SDRAM_CLK_PERIOD_NS : integer := 5;
    signal waitCounter : integer := 0;
    signal waitCounterInit0 : integer := 0;
    signal waitCounterInit1 : integer := 0;
    
    signal write_address       : unsigned(sdram_rowcount + log2(BANKCOUNT) + sdram_colcount - 1 downto 0) := (others=>'0'); -- address to write
    signal write_address_last  : unsigned(sdram_rowcount + log2(BANKCOUNT) + sdram_colcount - 1 downto 0) := (others=>'0'); -- address to write
    signal read_address_base   : unsigned(sdram_rowcount + log2(BANKCOUNT) + sdram_colcount - 1 downto 0) := (others=>'0'); -- address to read
    signal read_address_act    : unsigned(sdram_rowcount + log2(BANKCOUNT) + sdram_colcount - totaltapcountlog2 - 1 downto 0) := (others=>'0'); -- address to read

    signal   currInFifo : std_logic := '0';
    signal   currInstChanTapRead : unsigned(instcountlog2 + channelscountlog2 + tapsperchanlog2 -1 downto 0) := (others=>'0');
    signal   currInstChanTapWrite: unsigned(instcountlog2 + channelscountlog2 + tapsperchanlog2 -1 downto 0) := (others=>'0');
    constant taps_forbidden : unsigned(totaltapcountlog2 - 1 downto 0) := (others=>'0');
    -- delay tap position relative to current address
    signal TAP_LOCATION   : instcount_times_channelcount_times_delaytaps := (others=>(others=>'0'));
   
begin

-- Establish differential in and output buffers 

-- DQS, technically an INOUT, here strictly used as an out
DQSLOOP:
for byte in 0 to 1 generate

IOBUFDS_inst : IOBUFDS
generic map (
  DIFF_TERM => FALSE, -- Differential Termination (TRUE/FALSE)
  IBUF_LOW_PWR => TRUE, -- Low Power = TRUE, High Performance = FALSE
  IOSTANDARD => "BLVDS_25", -- Specify the I/O standard
  SLEW => "SLOW")       -- Specify the output slew rate
port map (
  O => SDRAM_DQS_in(byte),  -- Buffer output
  IO => SDRAM_DQS_P(byte),  -- Diff_p inout (connect directly to top-level port)
  IOB => SDRAM_DQS_N(byte), -- Diff_n inout (connect directly to top-level port)
  I => SDRAM_DQS_out(byte), -- Buffer input
  T => SDRAM_DQS_tri      -- 3-state enable input, high=input, low=output
);

end generate;

OBUFDS_inst : OBUFDS
generic map (
  IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
  SLEW => "FAST")          -- Specify the output slew rate
port map (
  O  => SDRAM_CLK_P,     -- Diff_p output (connect directly to top-level port)
  OB => SDRAM_CLK_N,   -- Diff_n output (connect directly to top-level port)
  I  => clk200      -- Buffer input 
);
 
DDR_REG_LOOP:
for i in 0 to sdramWidth-1 generate
   IDDR_inst : IDDR 
    generic map (
       DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE", "SAME_EDGE" 
                                        -- or "SAME_EDGE_PIPELINED" 
       INIT_Q1 => '0', -- Initial value of Q1: '0' or '1'
       INIT_Q2 => '0', -- Initial value of Q2: '0' or '1'
       SRTYPE => "SYNC") -- Set/Reset type: "SYNC" or "ASYNC" 
    port map (
       Q1 => Z01_FROM_RAMF_DI(0)(i), -- 1-bit output for positive edge of clock 
       Q2 => Z01_FROM_RAMF_DI(1)(i), -- 1-bit output for negative edge of clock
       C => clk200,   -- 1-bit clock input
       CE => '1', -- 1-bit clock enable input
       D => SDRAM_DATA_fromSDRAM_prebuf(i),   -- 1-bit DDR data input
       R => ram_rst100,   -- 1-bit reset
       S => '0'    -- 1-bit set
       );
   
      ODDR_inst : ODDR
   generic map(
      DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE" 
      INIT => '0',   -- Initial value for Q port ('1' or '0')
      SRTYPE => "SYNC") -- Reset Type ("ASYNC" or "SYNC")
   port map (
      Q => SDRAM_DATA_toSDRAM_prebuf(i),   -- 1-bit DDR output
      C => clk200,    -- 1-bit clock input
      CE => '1',  -- 1-bit clock enable input
      D1 => Z01_TO_RAMF_DO(0)(i),  -- 1-bit data input (positive edge)
      D2 => Z01_TO_RAMF_DO(1)(i),  -- 1-bit data input (negative edge)
      R => ram_rst100,    -- 1-bit reset input
      S => '0'     -- 1-bit set input
   );
   
   IOBUF_inst : IOBUF
   generic map (
      DRIVE => 12,
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW")
   port map (
      O  => SDRAM_DATA_fromSDRAM_prebuf(i),     -- Buffer output
      IO => SDRAM_DATA(i),   -- Buffer inout port (connect directly to top-level port)
      I  => SDRAM_DATA_toSDRAM_prebuf(i),     -- Buffer input
      T  => SDRAM_TRISTATE_EN      -- 3-state enable input, high=input, low=output 
   );
end generate;

DDRLOOP:
for word in 0 to 1 generate

TO_RAMF: FIFO_DUALCLOCK_MACRO
    generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0020",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0020", -- Sets the almost empty threshold
      DATA_WIDTH => sdramWidth,   -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb") INCLUDE 1 sync bit
      FIFO_SIZE => "18Kb",            -- Target BRAM, "18Kb" or "36Kb" 
      FIRST_WORD_FALL_THROUGH => TRUE) -- Sets the FIFO FWFT to TRUE or FALSE
    port map (
      ALMOSTEMPTY => TO_RAMF_ALMOSTEMPTY(word),   -- 1-bit output almost empty
      ALMOSTFULL  => TO_RAMF_ALMOSTFULL(word),    -- 1-bit output almost full
      DO          => TO_RAMF_DO(word),      -- Output data, width defined by DATA_WIDTH parameter
      EMPTY       => TO_RAMF_EMPTY(word),         -- 1-bit output empty
      FULL        => TO_RAMF_FULL(word),          -- 1-bit output full
      RDCOUNT     => TO_RAMF_RDCOUNT(word),       -- Output read count, width determined by FIFO depth
      RDERR       => TO_RAMF_RDERR(word),         -- 1-bit output read error
      WRCOUNT     => TO_RAMF_WRCOUNT(word),       -- Output write count, width determined by FIFO depth
      WRERR       => TO_RAMF_WRERR(word),         -- 1-bit output write error
      DI          => TO_RAMF_DI,-- Input data, width defined by DATA_WIDTH parameter
      RDCLK       => clk200,                -- 1-bit input read clock
      RDEN        => TO_RAMF_RDEN,          -- 1-bit input read 
      RST         => ram_rst100,            -- 1-bit input reset
      WRCLK       => clk100,                -- 1-bit input write clock
      WREN        => TO_RAMF_WREN(word)     -- 1-bit input write enable
    );
end generate;

FROM_RAMF: FIFO_DUALCLOCK_MACRO
    generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0080",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0020", -- Sets the almost empty threshold
      DATA_WIDTH => sdramWidth,        -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => "18Kb",            -- Target BRAM, "18Kb" or "36Kb" 
      FIRST_WORD_FALL_THROUGH => FALSE) -- Sets the FIFO FWFT to TRUE or FALSE
    port map (
      ALMOSTEMPTY => FROM_RAMF_ALMOSTEMPTY,   -- 1-bit output almost empty
      ALMOSTFULL  => FROM_RAMF_ALMOSTFULL,    -- 1-bit output almost full
      DO          => FROM_RAMF_DO,            -- Output data, width defined by DATA_WIDTH parameter
      EMPTY       => FROM_RAMF_EMPTY,         -- 1-bit output empty
      FULL        => FROM_RAMF_FULL,          -- 1-bit output full
      RDCOUNT     => FROM_RAMF_RDCOUNT,       -- Output read count, width determined by FIFO depth
      RDERR       => FROM_RAMF_RDERR,         -- 1-bit output read error
      WRCOUNT     => FROM_RAMF_WRCOUNT,       -- Output write count, width determined by FIFO depth
      WRERR       => FROM_RAMF_WRERR,         -- 1-bit output write error
      DI          => FROM_RAMF_DI,-- Input data, width defined by DATA_WIDTH parameter
      RDCLK       => clk100,                  -- 1-bit input read clock
      RDEN        => FROM_RAMF_RDEN,          -- 1-bit input read 
      RST         => ram_rst100,            -- 1-bit input reset
      WRCLK       => clk200,                  -- 1-bit input write clock
      WREN        => FROM_RAMF_WREN           -- 1-bit input write enable
    );
    
PARAMF: FIFO_DUALCLOCK_MACRO
    generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0020",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0020", -- Sets the almost empty threshold
      DATA_WIDTH => RAM_WIDTH18,        -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => "18Kb",            -- Target BRAM, "18Kb" or "36Kb" 
      FIRST_WORD_FALL_THROUGH => FALSE) -- Sets the FIFO FWFT to TRUE or FALSE
    port map (
      ALMOSTEMPTY => PARAMF_ALMOSTEMPTY,   -- 1-bit output almost empty
      ALMOSTFULL  => PARAMF_ALMOSTFULL,    -- 1-bit output almost full
      DO          => PARAMF_DO,            -- Output data, width defined by DATA_WIDTH parameter
      EMPTY       => PARAMF_EMPTY,         -- 1-bit output empty
      FULL        => PARAMF_FULL,          -- 1-bit output full
      RDCOUNT     => PARAMF_RDCOUNT,       -- Output read count, width determined by FIFO depth
      RDERR       => PARAMF_RDERR,         -- 1-bit output read error
      WRCOUNT     => PARAMF_WRCOUNT,       -- Output write count, width determined by FIFO depth
      WRERR       => PARAMF_WRERR,         -- 1-bit output write error
      DI          => std_logic_vector(PARAMF_DI),-- Input data, width defined by DATA_WIDTH parameter
      RDCLK       => clk200,                -- 1-bit input read clock
      RDEN        => PARAMF_RDEN,          -- 1-bit input read 
      RST         => ram_rst100,          -- 1-bit input reset
      WRCLK       => clk100,                -- 1-bit input write clock
      WREN        => PARAMF_WREN           -- 1-bit input write enable
    );
    
   -- Indicate the need to refresh when the counter is 2048,
   -- Force a refresh when the counter is 4096 - (if a refresh is forced, 
   -- multiple refresshes will be forced until the counter is below 2048
   pending_refresh <= refresh_count(11);
   forcing_refresh <= refresh_count(12);

   ----------------------------------------------------------------------------
   -- Seperate the address into row / bank / address
   ----------------------------------------------------------------------------   
   addr_row_wr  <= std_logic_vector(write_address(write_address'high                                    downto write_address'length - sdram_rowcount));
   addr_bank_wr <= std_logic_vector(write_address(write_address'high - sdram_rowcount                   downto write_address'length - sdram_rowcount- log2(BANKCOUNT) ));
   addr_col_wr  <= std_logic_vector(write_address(write_address'high - sdram_rowcount - log2(BANKCOUNT) downto 0));
   addr_row_rd  <= std_logic_vector(read_address_act(read_address_act'high                                    downto read_address_act'length - sdram_rowcount));
   addr_bank_rd <= std_logic_vector(read_address_act(read_address_act'high - sdram_rowcount                   downto read_address_act'length - sdram_rowcount- log2(BANKCOUNT) ));
   addr_col_rd_without_taps  <= std_logic_vector(read_address_act(read_address_act'high - sdram_rowcount - log2(BANKCOUNT) downto 0));

   -----------------------------------------------
   --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   --!! Ensure that all outputs are registered. !!
   --!! Check the pinout report to be sure      !!
   --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   -----------------------------------------------
   sdram_CS   <= iob_command(3);
   sdram_RAS  <= iob_command(2);
   sdram_CAS  <= iob_command(1);
   sdram_WE   <= iob_command(0);   
       
-- decide into which fifo write goes
wren_proc: process(clk100) 
  begin
     if rising_edge(clk100) then
        TO_RAMF_WREN <= "00";
        if initRam100 = '0' then
            if TO_RAMF_WRandTOG = '1' then
                if currInFifo = '0' then
                    TO_RAMF_WREN <= "01";
                else
                    TO_RAMF_WREN <= "10";
                end if;
                currInFifo <= not currInFifo;
            end if;
        end if;
     end if;
 end process;
           
------------------------------------------------
-- Handle the data coming back from the 
-- SDRAM for the Read transaction
------------------------------------------------
FROM_RAMF_WREN <= data_ready_delay(5);
TO_RAMF_RDEN   <= wr_burst_w_delay(2);
currInstChanTapRead <= read_address_base(totaltapcountlog2-1 downto 0);
main_proc: process(clk200) 
   begin
      if rising_edge(clk200) then
        
        FROM_RAMF_DI   <= Z01_FROM_RAMF_DI(0);
        
        Z01_TO_RAMF_DO <= TO_RAMF_DO;
    
        -- propagate wr_burst with delay
        wr_burst_w_delay <= '0' & wr_burst_w_delay(wr_burst_w_delay'high downto 1);
        PARAMF_RDEN <= '0';
        PARAMF_RDEN_Z01 <= PARAMF_RDEN;
        
        -- accept params from 100MHz domain
        if PARAMF_RDEN_Z01 = '1' then
            if PARAMF_DO(PARAMF_DO'high) = '0' then
                TAP_LOCATION(to_integer(currInstChanTapWrite)) <= unsigned(PARAMF_DO(TAP_LOCATION(0)'high downto 0));
            else
                currInstChanTapWrite <= unsigned(PARAMF_DO(currInstChanTapWrite'high downto 0));
            end if;
        elsif PARAMF_EMPTY = '0' and PARAMF_RDEN = '0' and initRam100 = '0' then
            PARAMF_RDEN <= '1';
        end if;
        
        ----------------------------------------------------------------------------
        -- update shift registers used to choose when to present data to/from memory
        ----------------------------------------------------------------------------
        data_ready_delay <= '0' & data_ready_delay(data_ready_delay'high downto 1);
        
        -- FSM starts here
        
        waitCounter <= waitCounter - 1;
        waitCounterInit0  <= waitCounterInit0 - 1;
        waitCounterInit1  <= waitCounterInit1 - 1;
        sdram_laststate <= sdram_state;
        ------------------------------------------------
        -- Default sdram_state is to do nothing
        ------------------------------------------------
        sdram_addr     <= (others => '0');
        --sdram_ba       <= (others => '0');

        ------------------------------------------------
        -- countdown for initialisation & refresh
        ------------------------------------------------
        refresh_count <= refresh_count+1;
        
        case sdram_state is 
        when s_init1 =>
            sdram_addr     <= (others => '0');
            waitCounterInit0 <= 200000/SDRAM_CLK_PERIOD_NS;
            sdram_state <= s_init2;
            -- Apply NOP
            iob_command <= CMD_NOP;       
        -- step 2: maintain stable clock for 200uS (200000ns)
        when s_init2 =>
            if waitCounterInit0 = 0 then
                sdram_state <= s_init3;
            end if;
        -- step 3: apply NOP or Deselect and take CKE high
        when s_init3 => 
            SDRAM_CKE <= '1';
            waitCounterInit0 <= 400/SDRAM_CLK_PERIOD_NS;
            sdram_state <= s_init4;
        
        -- step 4: wait 400nS, 
        when s_init4 =>
            if waitCounterInit0 = 0 then
                sdram_state <= s_init5;
            end if;
        --then apply precharge all command
        when s_init5 =>
            iob_command <= CMD_PRECHARGE;     
            SDRAM_ADDR(10) <= '1';
            sdram_state <= s_init6;
        
        -- EMRS command to EMR 2
        when s_init6 =>  
            SDRAM_ADDR(10) <= '0';
            -- the following sets ERMS/MODE
            iob_command <= CMD_LOAD_MODE_REG;        
            SDRAM_BA <= EMR2;
            -- address still 0
            sdram_state <= s_init7;
        
        -- EMRS command to EMR 3
        when s_init7 =>      
            SDRAM_BA <= EMR3;
            -- address still 0
            sdram_state <= s_init8;
        
        -- EMRS to enable DLL (EMR 1)
        when s_init8 =>
            SDRAM_BA   <= EMR1;
            SDRAM_ADDR <= EMR1_SET_exit;
            sdram_state <= s_init9;
        
        -- Mode Reg Set for DLL Reset
        when s_init9 =>
            SDRAM_BA   <= MRS;
            SDRAM_ADDR <= MRS_SET;
            sdram_state <= s_init10;
        
        -- precharge all
        when s_init10 => 
            iob_command <= CMD_PRECHARGE;     
            sdram_addr     <= (others => '0');
            SDRAM_ADDR(10) <= '1';
            sdram_state <= s_init11;
            waitCounterInit0 <= 4;
        
        -- 2+ Auto Refresh Commands (in 200MHz clocks)
        when s_init11=>
            --AutoRefresh command
            iob_command <= CMD_REFRESH;   
            if waitCounterInit0 = 0 then
                sdram_state <= s_init12;
            end if;
        
        -- MRS command with LOW to A8    
        when s_init12=>
            iob_command <= CMD_LOAD_MODE_REG;
            SDRAM_BA   <= MRS;   
            SDRAM_ADDR <= MRS_SET;
            SDRAM_ADDR(8) <= '0';
            waitCounterInit0 <= 404;
            sdram_state <= s_init13;
        
        -- wait 200 clocks, then execute OCD callibration
        -- (using default config)
        when s_init13 => 
            -- apply nop
            iob_command <= CMD_NOP;    
            SDRAM_BA   <= EMR1;
            SDRAM_ADDR <= EMR1_SET_enter;
            
            if waitCounterInit0 = 0 then
                sdram_state <= s_init14;
            end if;
        
        when s_init14 => 
            -- ocd callibrate
            iob_command <= CMD_LOAD_MODE_REG;
            sdram_state <= s_init15;
            
        when s_init15 => 
            SDRAM_ADDR <= EMR1_SET_exit;
            sdram_state <= s_idle_in_wait;
            waitCounterInit1 <= 404;
            
        when s_idle_in_wait => 
            iob_command <= CMD_NOP;
            if waitCounterInit1 = 0 then
                sdram_state <= s_idle;
            end if;
            
        when s_idle =>
        
            -- tristate SDRAM
            SDRAM_TRISTATE_EN <= '1';
            
            -- Apply NOP
            iob_command <= CMD_NOP;
            
            -- Priority is to issue a refresh if one is outstanding
            if pending_refresh = '1' or forcing_refresh = '1' then
                ------------------------------------------------------------------------
                -- Start the refresh cycle. 
                -- This tasks tRFC (105ns)
                -- 105e-9 / (1/200e6) = 84
                ------------------------------------------------------------------------
                sdram_state <= s_idle_in_wait;
                waitCounterInit1 <= 84;
                iob_command <= CMD_REFRESH;
                refresh_count <= refresh_count - cycles_per_refresh+1;
            -- unless fromRam fifo is nearly full, read the next tap 
            -- and 
            elsif FROM_RAMF_ALMOSTFULL = '0' then
                sdram_state <= s_open_in_2;
                iob_command <= CMD_ACTIVE;
                sdram_addr  <= addr_row_rd;
                sdram_ba    <= addr_bank_rd;             
                isRead      <= '1';  
                            
            -- if TORAMF high buffer is not almost empty, initiate a write sequence
            elsif TO_RAMF_ALMOSTEMPTY(1) = '0' then
                --------------------------------
                -- Start the read or write cycle. 
                -- First task is to open the row
                --------------------------------
                sdram_state <= s_open_in_2;
                iob_command <= CMD_ACTIVE;
                sdram_addr  <= addr_row_wr;
                sdram_ba    <= addr_bank_wr;         
                isRead      <= '0';
            end if;               
        
        --------------------------------------------
        -- Opening the row ready for reads or writes
        --------------------------------------------
        when s_open_in_2 => 
            -- increment address to implement rolling delay line
            -- read address should track write address fairly closely
            sdram_state <= s_open_in_1;
        when s_open_in_1 =>
            -- write/read as necessary
            if isRead = '0' then
            sdram_state <= s_write_1;
            else
            SDRAM_TRISTATE_EN <= '1';
            sdram_state<= s_read_1;
            end if;
        
        ----------------------------------
        -- Processing the read transaction
        ----------------------------------
        when s_read_1 =>
            sdram_state     <= s_read_2;
            iob_command     <= CMD_READ;
            sdram_addr(sdram_addr'high downto sdram_addr'length - sdram_colcount)  <= (others=>'0'); 
            sdram_addr(sdram_colcount-1 downto 0)  <= addr_col_rd_without_taps & std_logic_vector(currInstChanTapRead); 
            sdram_ba        <= addr_bank_rd;
            sdram_addr(prefresh_cmd) <= '1'; -- A10 actually matters - it selects auto precharge
            
            -- Schedule reading the data value off the bus
            data_ready_delay((AL + CL)*2 + BURST_MAX downto (AL + CL)*2 + 1) <= BURST_PATTERN_RD;
            -- increment read address base
            read_address_base <= read_address_base + 1;
        
        -- wait for auto-precharge
        when s_read_2 =>
            iob_command <= CMD_NOP;
            sdram_state <= s_idle_in_wait;
            waitCounterInit1 <= 1;
            read_address_act <= read_address_base(read_address_base'high downto totaltapcountlog2) - TAP_LOCATION(to_integer(currInstChanTapRead));
        
        -- FOR SIMPLICITY, ASSUME NO READ B2B
        
        -- if new read bank and row are equivalent to the last one, back-to-back
        --if FROM_RAMF_ALMOSTFULL(0) = '0' and read_address(read_address'high downto sdram_colcount) = read_address_last(read_address'high downto sdram_colcount) then
        --    sdram_state     <= s_read_1;
        --end if;
        
        
        ------------------------------------------------------------------
        -- Processing the write transaction
        -------------------------------------------------------------------
        when s_write_1 =>
            iob_command        <= CMD_WRITE;
            sdram_addr(sdram_addr'high downto sdram_addr'length - sdram_colcount)  <= (others=>'0'); 
            sdram_addr(sdram_colcount-1 downto 0) <= addr_col_wr; 
            sdram_addr(prefresh_cmd)    <= '0'; -- A10 actually matters - it selects auto precharge
            sdram_ba           <= addr_bank_wr;
            wr_burst_w_delay(wr_burst_w_delay'high downto wr_burst_w_delay'length - BURST_MAX) <= BURST_PATTERN_WR;
            waitCounter <= RL;
        
            -- no need for a wait if performing back-to-back
            if sdram_laststate = s_write_3 then
                sdram_state <= s_write_3;
            else
                sdram_state <= s_write_wait;
            end if;
            
            -- increment write address and save last one
            write_address<= write_address + BL;
            write_address_last <= write_address;
        
        when s_write_wait =>
            iob_command        <= CMD_NOP;
            SDRAM_TRISTATE_EN <= '0';
            -- send NOPs until RL period finished
            if waitCounter = 0 then
                sdram_state <= s_write_3;
            end if; 
        
        when s_write_3 =>
            
            -- Although it looks right in simulation you can't go write-to-read 
            -- here due to bus contention, as iob_dq_hiz takes a few ns.
            sdram_state   <= s_write_4;
            -- can we do a back-to-back write?
            if TO_RAMF_ALMOSTEMPTY(1) = '0' and write_address = write_address_last then
                sdram_state     <= s_write_1;
            end if;
            
        when s_write_4 =>  -- must wait tRDL, hence the extra idle sdram_state
            sdram_state <= s_precharge;
        
        -------------------------------------------------------------------
        -- Closing the row off (this closes all banks)
        -------------------------------------------------------------------
        when s_precharge =>
            sdram_state     <= s_idle_in_wait;
            -- need to wait 12.5nS, or 6 clocks
            waitCounterInit1  <= 6;
            iob_command     <= CMD_PRECHARGE;
            sdram_addr(prefresh_cmd) <= '1'; -- A10 actually matters - it selects all banks or just one
        
        -------------------------------------------------------------------
        -- We should never get here, but if we do then reset the memory
        -------------------------------------------------------------------
        when others => 
            sdram_state           <= s_init1;
        end case;
        
        if reset = '1' then  -- Sync reset
            sdram_state           <= s_init1;
        end if;
    end if;    
end process;
end Behavioral;