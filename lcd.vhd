----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz> 
-- Julian Loiacono 6/2016
--
--
-- Description: Generate an low-volume sine wave, at around 400 Hz
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

Library work;
use work.memory_word_type.all;


entity lcd is
    Generic(
        WAITCLOCKS : integer;
        PRESCALE   : integer
    );
    Port ( 
        clkin   : in STD_LOGIC;  
        LCDFIFO_ALMOSTFULL : out std_logic;
        LCD_RST : out std_logic := '0';
        LCD_CSX : out std_logic := '0';
        LCD_WRX : out std_logic := '1';
        LCD_RDX : out std_logic := '1';
        LCD_DCX : out std_logic := '1';
        LCD_D   : inout std_logic_vector(17 downto 0) := (others=>'0');
        LCD_IM  : out std_logic_vector(3 downto 0) := "0011";
        LCDFIFO_DI    : in std_logic_vector (std_flowwidth-1 downto 0);
        LCDFIFO_WREN  : in STD_LOGIC;
        ram_rst : in std_logic;
        InitRam : in std_logic
       );
           
end lcd;
architecture Behavioral of lcd is

constant ILI9341_CASET : unsigned(17 downto 0) := to_unsigned(42, ram_width18);   --< Column Address Set
constant ILI9341_PASET : unsigned(17 downto 0) := to_unsigned(43, ram_width18);      --< Page Address Set
constant ILI9341_RAMWR : unsigned(17 downto 0) := to_unsigned(44, ram_width18);      --< Memory Write

signal Z01_LCD_D   : std_logic_vector(17 downto 0) := (others=>'0');
signal LCDFIFO_DO          : std_logic_vector (std_flowwidth-1 downto 0);
signal LCDFIFO_ALMOSTEMPTY : std_logic;
signal LCDFIFO_EMPTY       : std_logic;
signal LCDFIFO_FULL        : std_logic;
signal LCDFIFO_RDCOUNT     : std_logic_vector (8 downto 0);
signal LCDFIFO_RDERR       : std_logic;
signal LCDFIFO_WRCOUNT     : std_logic_vector (8 downto 0);
signal LCDFIFO_WRERR       : std_logic;
signal LCDFIFO_RDEN        : std_logic := '0';
        
attribute mark_debug : string;
attribute mark_debug of LCD_RST: signal is "true";
attribute mark_debug of LCD_CSX: signal is "true";
attribute mark_debug of LCD_WRX: signal is "true";
attribute mark_debug of LCD_RDX: signal is "true";
attribute mark_debug of LCD_DCX: signal is "true";
attribute mark_debug of Z01_LCD_D: signal is "true";

signal LCD_CLK_int : std_logic := '0';
signal DATA_TO_SEND : unsigned(17 downto 0) := (others=>'0');
signal SQUARESBITMAP : std_logic_vector(17 downto 0) := (others=>'0');

constant ILI9341_TFTWIDTH   : integer := 240;      --< ILI9341 max TFT width >--
constant ILI9341_TFTHEIGHT  : integer := 320;      --< ILI9341 max TFT height >--

signal READS_LEFT : integer := 0;
signal D_or_C : std_logic := '1';

type lcd_fsm_state is (
    s_reset,           -- 0
    s_fillrect, 
    s_startwrite, 
    s_waitforread,
    s_setrow, 
    s_setcol, -- 1 -- 1 
    s_drawsquares,
    s_idle,            -- 0
    s_waitforfifo,   -- 0
    s_processfifo,   -- 0
    s_write,
    s_write0, -- 1 
    s_write1,      -- 2
    s_read,
    s_read0, -- 1 
    s_read1      -- 2
    );
    
signal lcdstate_after_write: lcd_fsm_state := s_idle;
signal lcdstate_after_fillrect: lcd_fsm_state := s_idle;
signal lcdstate_after_setcol: lcd_fsm_state := s_idle;
signal lcdstate_after_startwrite: lcd_fsm_state := s_idle;
signal lcdstate     : lcd_fsm_state := s_idle;
attribute mark_debug of lcdstate: signal is "true";
attribute FSM_ENCODING : string;
attribute FSM_ENCODING of lcdstate : signal is "ONE-HOT";

type dataFunctionType is (
    d_fromArray,
    d_phase
  );
  
signal dataFunction : dataFunctionType := d_fromArray;

signal prescale_counter: std_logic := '0';

constant LCD_HEIGHT : unsigned(8 downto 0) := to_unsigned(320, 9);
constant LCD_WIDTH  : unsigned(7 downto 0) := to_unsigned(240, 8);
signal counter : integer := 0;
signal LCD_INITCOUNT: integer := 0;
signal RECTWIDTH : unsigned(7 downto 0) := (others=>'0');
signal RECTHEIGHT: unsigned(8 downto 0) := (others=>'0');
signal X : unsigned(7 downto 0) := (others=>'0');
signal Y : unsigned(8 downto 0) := (others=>'0');

signal X0 : unsigned(7 downto 0) := (others=>'0');
signal X1 : unsigned(7 downto 0) := (others=>'0');
signal Y0 : unsigned(8 downto 0) := (others=>'0');
signal Y1 : unsigned(8 downto 0) := (others=>'0');

constant COLOR_WIDTH : integer := RAM_WIDTH18;
signal BASECOLOR      : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal R : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal G : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal B : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal rowR : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal rowG : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal rowB : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal dRx : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal dGx : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal dBx : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal dRy : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal dGy : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');
signal dBy : unsigned(COLOR_WIDTH-1 downto 0) := (others=>'0');


begin

pipeline: process(clkin)
    begin
        if rising_edge(clkin) then
            if InitRam = '0' then
            Z01_LCD_D <= LCD_D;
            LCDFIFO_RDEN <= '0';
            prescale_counter <= not prescale_counter;
            if prescale_counter = '0' then
                LCD_CLK_int <= not LCD_CLK_int;
                
                case lcdstate is
                when s_reset => 
                    counter <= counter + 1;
                    if counter = 0 then
                        LCD_RST <= '1';    
                    elsif counter = WAITCLOCKS then
                        LCD_RST <= '0';   
                    elsif counter = WAITCLOCKS*2 then
                        LCD_RST <= '1';    
                    elsif counter = WAITCLOCKS*3 then
                        lcdstate <= s_idle;
                        counter  <= 0;
                    end if;
                    
                when s_idle =>
                    LCD_D <= (others=>'0');
                    if LCDFIFO_EMPTY = '0' then
                        LCDFIFO_RDEN <= '1';
                        lcdstate <= s_waitforread;
                    end if;
                
                when s_waitforread => 
                    lcdstate <= s_processfifo;
                
                when s_processfifo =>
                    DATA_TO_SEND <= unsigned(LCDFIFO_DO(17 downto 0));
                    D_or_C       <= '1';
                    -- bit 19 is reset
                    case LCDFIFO_DO(std_flowwidth -1 downto std_flowwidth -3) is
                    when LCD_COMMAND =>
                        READS_LEFT<= to_integer(unsigned(LCDFIFO_DO(24 downto 21)));
                        lcdstate  <= s_write;
                        D_or_C    <= '0';
                    when LCD_DATA  =>
                        lcdstate <= s_write;
                    when LCD_RESET =>
                        lcdstate <= s_reset;
                    when LCD_FILLRECT => 
                        lcdstate  <= s_startwrite;                
                        lcdstate_after_startwrite <= s_fillrect;
                        lcdstate_after_fillrect   <= s_idle;
                        R <= BASECOLOR(17 downto 12) & "000000000000";
                        G <= BASECOLOR(11 downto  6) & "000000000000";
                        B <= BASECOLOR(5  downto  0) & "000000000000";
                        
                        rowR <= (unsigned(BASECOLOR(17 downto 12)) & "000000000000") + dRy;
                        rowG <= (unsigned(BASECOLOR(11 downto  6)) & "000000000000") + dGy;
                        rowB <= (unsigned(BASECOLOR(5 downto   0)) & "000000000000") + dBy;
                        
                    when LCD_SETCOLOR =>
                        lcdstate <= s_idle;
                        case LCDFIFO_DO(20 downto 18) is
                        when COLOR_BASE => 
                            BASECOLOR  <= unsigned(LCDFIFO_DO(COLOR_WIDTH-1 downto 0));
                        when COLOR_dRx =>  
                            dRx  <= unsigned(LCDFIFO_DO(COLOR_WIDTH-1 downto 0));
                        when COLOR_dGx =>  
                            dGx  <= unsigned(LCDFIFO_DO(COLOR_WIDTH-1 downto 0));
                        when COLOR_dBx => 
                            dBx  <= unsigned(LCDFIFO_DO(COLOR_WIDTH-1 downto 0));
                        when COLOR_dRy => 
                            dRy  <= unsigned(LCDFIFO_DO(COLOR_WIDTH-1 downto 0));
                        when COLOR_dGy => 
                            dGy  <= unsigned(LCDFIFO_DO(COLOR_WIDTH-1 downto 0));
                        when COLOR_dBy => 
                            dBy  <= unsigned(LCDFIFO_DO(COLOR_WIDTH-1 downto 0));
                        when others=>

                        end case;
                        
                    when LCD_SETCOLUMN => 
                        X0 <= unsigned(LCDFIFO_DO(16 downto 9));
                        X1 <= unsigned(LCDFIFO_DO(7  downto 0));
                        -- calculate the width as X1 - X0
                        RECTWIDTH <= unsigned(LCDFIFO_DO(7 downto 0)) - unsigned(LCDFIFO_DO(16 downto 9)) + 1;
                        lcdstate <= s_setcol;
                        lcdstate_after_setcol <= s_idle;
                    when LCD_SETROW => 
                        Y0 <= unsigned(LCDFIFO_DO(17 downto 9));
                        Y1 <= unsigned(LCDFIFO_DO(8 downto 0));
                        -- calculate the height as X1 - X0
                        RECTHEIGHT <= unsigned(LCDFIFO_DO(8 downto 0)) - unsigned(LCDFIFO_DO(17 downto 9)) + 1;
                        lcdstate <= s_setrow;
                    when LCD_DRAWSQUARES => 
                        SQUARESBITMAP <= LCDFIFO_DO(17 downto 0);
                        lcdstate <= s_drawsquares;
                    when others => 
                    end case;
                    
                -- draw squares when indicated in the bitmap 
                when s_drawsquares =>
                    SQUARESBITMAP <= SQUARESBITMAP(16 downto 0) & '0';
                    -- advance in x-direction
                    X0 <= X0 + RECTWIDTH;
                    X1 <= X1 + RECTWIDTH;
                    
                    -- if this square is indicated, change row address and fill it
                    if SQUARESBITMAP(17) = '1' then
                        lcdstate <= s_setcol;
                        lcdstate_after_setcol  <= s_startwrite;                
                        lcdstate_after_startwrite <= s_fillrect;
                        lcdstate_after_fillrect <= s_drawsquares;
                    end if;
                    if unsigned(SQUARESBITMAP) = 0 then
                        lcdstate <= s_idle; 
                    end if;
                
                when s_startwrite =>
                    -- write to ram
                    DATA_TO_SEND <= ILI9341_RAMWR;
                    D_or_C <= '0';
                    lcdstate <= s_write;
                    lcdstate_after_write <= lcdstate_after_startwrite;
                
                -- set the X0 and X1 box coordinates on ILI
                when s_setcol =>
                    lcdstate <= s_write;
                    lcdstate_after_write <= s_setcol;
                    counter <= counter + 1;
                    
                    case counter is
                    when 0 =>
                        -- send width instruction
                        DATA_TO_SEND <= ILI9341_CASET;
                        D_or_C <= '0';
                    when 1 =>
                        -- send 0
                        DATA_TO_SEND <= (others=>'0');
                        D_or_C <= '1';
                    when 2 =>
                        -- send X0, low byte
                        DATA_TO_SEND <= "0000000000" & X0(7 downto 0);
                    when 3 => 
                        -- send 0
                        DATA_TO_SEND <= (others=>'0');
                    when others =>
                        -- send X1, low byte
                        DATA_TO_SEND <= "0000000000" & X1(7 downto 0);
                        -- reset counter
                        counter <= 0;
                        -- return to idle
                        lcdstate_after_write <= lcdstate_after_setcol;
                    end case;
                    
                -- set the Y0 and Y1 box coordinates on ILI
                when s_setrow =>
                    lcdstate <= s_write;
                    lcdstate_after_write <= s_setrow;
                    counter <= counter + 1;
                    DATA_TO_SEND <= (others=>'0');
                    
                    case counter is
                    when 0 =>
                        -- send length instruction
                        DATA_TO_SEND <= ILI9341_PASET;
                        D_or_C <= '0';
                    when 1 =>
                        -- send Y0, high byte
                        DATA_TO_SEND(0) <= Y0(8);
                        D_or_C <= '1';
                    when 2 =>
                        -- send Y0, low byte
                        DATA_TO_SEND(7 downto 0) <= Y0(7 downto 0);
                    when 3 => 
                        -- send Y1, low byte
                        DATA_TO_SEND(0) <= Y1(8);
                    when others =>
                        -- send X1, low byte
                        DATA_TO_SEND(7 downto 0) <= Y1(7 downto 0);
                        -- reset counter
                        counter <= 0;
                        -- return to idle
                        lcdstate_after_write <= s_idle;
                    end case;
                    
                when s_fillrect =>
                    lcdstate <= s_write;
                    lcdstate_after_write <= s_fillrect;
                    
                    X <= X+1;
                    R <= R + dRx;
                    G <= G + dGx;
                    B <= B + dBx;
                    DATA_TO_SEND <= R(COLOR_WIDTH-1 downto COLOR_WIDTH-6) & G(COLOR_WIDTH-1 downto COLOR_WIDTH-6) & B(COLOR_WIDTH-1 downto COLOR_WIDTH-6);
                    D_or_C <= '1';
                    
                    if X = RECTWIDTH-1 then
                        R <= rowR;
                        G <= rowG;
                        B <= rowB;
                        
                        rowR <= rowR + dRy;
                        rowG <= rowG + dGy;
                        rowB <= rowB + dBy;
                        X <= (others=>'0');
                        Y <= Y + 1;
                        if Y = RECTHEIGHT-1 then
                            X <= (others => '0');
                            Y <= (others => '0');
                            lcdstate_after_write <= lcdstate_after_fillrect;
                        end if;
                    end if;
                
                when s_write =>
                    LCD_DCX <= D_or_C; 
                    --LCD_CSX <= '0';
                    LCD_WRX <= '0';
                    lcdstate <= s_write0;
                    LCD_D <= std_logic_vector(DATA_TO_SEND);
                    
                when s_write0 =>
                    LCD_WRX <= '1';
                    lcdstate <= s_write1;
                    
                when s_write1 =>
                    --LCD_CSX <= '1';
                    if READS_LEFT = 0 then
                        lcdstate <= lcdstate_after_write;     
                    else
                        lcdstate <= s_read;     
                    end if;
                    
                when s_read =>
                    READS_LEFT <= READS_LEFT -1;
                    --LCD_CSX <= '0';
                    LCD_RDX <= '0';
                    lcdstate <= s_read0;
                    LCD_D <= (others=>'Z');
                    
                when s_read0 =>
                    LCD_RDX <= '1';
                    lcdstate <= s_read1;
                    
                when s_read1 =>
                    --LCD_CSX <= '1';
                    if READS_LEFT = 0 then
                        lcdstate <= lcdstate_after_write;  
                    else
                        lcdstate <= s_read;     
                    end if;
                when others =>
                end case;
            end if;
            end if;
        end if;
    end process;
    
    
   FIFO_SYNC_MACRO_inst : FIFO_SYNC_MACRO
   generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5, "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0080",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0080", -- Sets the almost empty threshold
      DATA_WIDTH => std_flowwidth,   -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => "18Kb")            -- Target BRAM, "18Kb" or "36Kb" 
   port map (
      ALMOSTEMPTY => LCDFIFO_ALMOSTEMPTY,   -- 1-bit output almost empty
      ALMOSTFULL => LCDFIFO_ALMOSTFULL,     -- 1-bit output almost full
      DO => LCDFIFO_DO,                     -- Output data, width defined by DATA_WIDTH parameter
      EMPTY => LCDFIFO_EMPTY,               -- 1-bit output empty
      FULL => LCDFIFO_FULL,                 -- 1-bit output full
      RDCOUNT => LCDFIFO_RDCOUNT,           -- Output read count, width determined by FIFO depth
      RDERR => LCDFIFO_RDERR,               -- 1-bit output read error
      WRCOUNT => LCDFIFO_WRCOUNT,           -- Output write count, width determined by FIFO depth
      WRERR => LCDFIFO_WRERR,               -- 1-bit output write error
      CLK => clkin,                        -- 1-bit input clock
      DI => LCDFIFO_DI,                     -- Input data, width defined by DATA_WIDTH parameter
      RDEN => LCDFIFO_RDEN,                 -- 1-bit input read enable
      RST => ram_rst,                       -- 1-bit input reset
      WREN => LCDFIFO_WREN                  -- 1-bit input write enable
   );
end Behavioral;
