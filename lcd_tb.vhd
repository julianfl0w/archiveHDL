----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/22/2018 01:22:18 PM
-- Design Name: 
-- Module Name: lcd_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

Library work;
use work.memory_word_type.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lcd_tb is
--  Port ( );
end lcd_tb;

architecture Behavioral of lcd_tb is

COMPONENT lcd
    Generic(
        WAITCLOCKS : integer;
        PRESCALE   : integer
    );
    Port ( 
            clkin   : in STD_LOGIC;  
            LCDFIFO_ALMOSTFULL : out std_logic;
            LCD_RST : out std_logic := '0';
            LCD_CSX : out std_logic := '1';
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
end component;

component ram_active_rst is
Port ( clkin      : in STD_LOGIC;
       clksRdy    : in STD_LOGIC;
       ram_rst    : out STD_LOGIC := '0';
       initializeRam_out0 : out std_logic := '1';
       initializeRam_out1 : out std_logic := '1'
       );
end component;

signal clk100  : STD_LOGIC;  
signal LCD_RST : std_logic := '1';
signal LCD_CSX : std_logic := '1'; 
signal LCD_WRX : std_logic := '1';
signal LCD_RDX : std_logic := '1';
signal LCD_DCX : std_logic := '1';
signal LCD_D   : std_logic_vector(17 downto 0) := (others=>'0');
signal LCD_IM  : std_logic_vector(3 downto 0) := "0011";
signal LCD_WRX_last : std_logic := '1'; 

type rbType is array(0 to 255, 0 to 15) of std_logic_vector(7 downto 0);
signal regBank : rbType := (others=>(others=>(others=>'0')));
signal regaddr : unsigned(7 downto 0) := (others=>'0');
signal dataNo : integer := 0;

constant clk100_period : time := 20 ns;

signal LCDFIFO_DI    : std_logic_vector (std_flowwidth-1 downto 0) := (others=>'0');
signal LCDFIFO_WREN  : STD_LOGIC := '0';
signal ram_rst : std_logic := '0';
signal clksRdy : std_logic := '1';
signal initRam : std_logic := '0';
signal initRam1 : std_logic := '0';

signal LCDFIFO_ALMOSTFULL : std_logic;

begin

i_lcd: lcd 
generic map(
    WAITCLOCKS => 72,
    PRESCALE   => 2
)

port map (
    clkin   => clk100,  
    LCDFIFO_ALMOSTFULL => LCDFIFO_ALMOSTFULL,
    LCD_RST => LCD_RST,
    LCD_CSX => LCD_CSX,
    LCD_WRX => LCD_WRX,
    LCD_RDX => LCD_RDX,
    LCD_DCX => LCD_DCX,
    LCD_D   => LCD_D,
    LCD_IM  => LCD_IM,
    LCDFIFO_DI    => LCDFIFO_DI,
    LCDFIFO_WREN  => LCDFIFO_WREN,
    ram_rst => ram_rst,
    InitRam => InitRam
); 


i_ram_active_rst: ram_active_rst port map(
    clkin              => clk100,
    clksRdy            => clksRdy, 
    ram_rst            => ram_rst,
    initializeRam_out0  => initRam,    
    initializeRam_out1  => initRam1
    );

-- Clock process definitions( clock with 50% duty cycle is generated here.
clk100_process: process
begin
    clk100 <= '0';
    wait for clk100_period/2;  --for 0.5 ns signal is '0'.
    clk100 <= '1';
    wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;

data_in_process: process(clk100)
begin
    if rising_edge(clk100) then
        LCD_WRX_last <= LCD_WRX; 
        
        -- on the rising edge of writeclock
        if LCD_WRX_last = '0' and LCD_WRX = '1' then
            -- if this chip is selected
            if LCD_CSX = '0' then
                -- if instruction
                if LCD_DCX = '0' then
                    regaddr <= unsigned(LCD_D(7 downto 0));
                    dataNo  <= 0;
                else
                    if regaddr /= X"2C" then
                        regBank(to_integer(regaddr), dataNo) <= LCD_D(7 downto 0);
                    end if;
                    dataNo <= dataNo + 1;
                end if;
            end if;
        end if;
        
    end if;
end process;

init_process: process
begin
    wait until initRam = '0';
    wait until rising_edge(clk100);
    LCDFIFO_WREN <= '1';
                --     FRC
    LCDFIFO_DI <= LCD_COMMAND  & "011010101010101010101"; -- command
    wait until rising_edge(clk100);
    LCDFIFO_DI <= LCD_DATA     & "000101010101010101010"; -- 1x data write
    wait until rising_edge(clk100);
    LCDFIFO_DI <= LCD_COMMAND  & "001101010101010101010"; -- command with 3 reads after 
    wait until rising_edge(clk100);
    LCDFIFO_DI <= LCD_SETCOLOR & COLOR_BASE & "000000000000000000"; -- set color 0 to black 
    wait until rising_edge(clk100);
    LCDFIFO_DI <= LCD_SETCOLOR & COLOR_dBx  & "000000000000100000"; -- set x-delta for blue
    wait until rising_edge(clk100);
    LCDFIFO_DI <= LCD_SETCOLOR & COLOR_dBy  & "000000000000010000"; -- set y-delta for blue
    wait until rising_edge(clk100);
    LCDFIFO_DI <= LCD_SETCOLUMN & std_logic_vector(to_unsigned(4, 21)); -- set width to 4
    wait until rising_edge(clk100);
    LCDFIFO_DI <= LCD_SETROW & std_logic_vector(to_unsigned(4, 21)); -- set height to 4
    wait until rising_edge(clk100);
    LCDFIFO_DI <= LCD_FILLRECT & "000000000000000000000"; -- draw rect, data irrelevant
    wait until rising_edge(clk100);
    LCDFIFO_DI <= (others=>'0');
    LCDFIFO_WREN <= '0';
end process;


end Behavioral;
