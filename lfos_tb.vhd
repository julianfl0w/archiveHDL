library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY lfos_tb IS 
END lfos_tb;

ARCHITECTURE behavior OF lfos_tb IS
-- Component Declaration for the Unit Under Test (UUT)

COMPONENT lfos
--just copy and paste the input and output ports of your module as such. 
Port ( 
    clk100         : in STD_LOGIC;
    LFO_RESET      : in unsigned(lfocount-1 downto 0);
    LFO_PHASEREF   : in LFOcount_by_lfocountlog2;
    LFO_INCREF     : in LFOcount_by_lfocountlog2;
    LFO_ALIGN      : in LFOcount_by_ramwidth18;
    LFO_WF         : in LFOcount_by_wfcountlog2;
    LFO_INCREMENT  : in LFOcount_by_ramwidth18;
    LFO_DEPTH      : in LFOcount_by_ramwidth18;
    LFO            : out LFOcount_by_ramwidth18 := (others=>(others=>'0'));
        
    initRam100      : in std_logic;
    OUTSAMPLEF_ALMOSTFULL: in std_logic
    );
       
END COMPONENT;

-- Clock period definitions
constant clk100_period : time := 10 ns;
signal clk100          : STD_LOGIC := '0';
signal LFO_INCREMENT   : LFOcount_by_ramwidth18 := (others=>(others=>'0'));
signal LFO             : LFOcount_by_ramwidth18 := (others=>(others=>'0'));

signal LFO_RESET   : unsigned(15 downto 0) := (others=>'0');
signal LFO_ALIGN   : LFOcount_by_ramwidth18   := (others=>(others=>'0'));
signal LFO_WF      : LFOcount_by_wfcountlog2  := (others=>0);
signal LFO_DEPTH   : LFOcount_by_ramwidth18   := (others=>(others=>'0'));

signal LFO_INCREF     : LFOcount_by_lfocountlog2 := (others=>0);
signal LFO_PHASEREF   : LFOcount_by_lfocountlog2 := (others=>0);

signal initRam100        : std_logic := false;
signal OUTSAMPLEF_ALMOSTFULL: std_logic:= '0';
    
BEGIN
-- Instantiate the Unit Under Test (UUT)
i_lfos: lfos PORT MAP (
    clk100         => clk100,
    LFO_RESET      => LFO_RESET,
    LFO_PHASEREF   => LFO_PHASEREF,
    LFO_INCREF     => LFO_INCREF,
    LFO_ALIGN      => LFO_ALIGN,
    LFO_WF         => LFO_WF,
    LFO_INCREMENT  => LFO_INCREMENT,
    LFO_DEPTH      => LFO_DEPTH,
    LFO            => LFO,
    initRam100        => initRam100,
    OUTSAMPLEF_ALMOSTFULL=> OUTSAMPLEF_ALMOSTFULL
    ); 

-- Clock process definitions( clock with 50% duty cycle is generated here.
clk100_process: process
begin
    clk100 <= '0';
    wait for clk100_period/2;  --for 0.5 ns signal is '0'.
    clk100 <= '1';
    wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;
   
lfotest: process
begin
    wait for clk100_period/4;
    LFO_INCREMENT(0)  <= to_signed(900, 18);
    LFO_DEPTH(0)      <= to_signed(2**17-1, 18);
    LFO_ALIGN(0)      <= to_signed(0, 18);
    LFO_WF(0)         <= WF_SINE_I;
    LFO_INCREF(0)     <= 1;
    LFO_PHASEREF(0)   <= 0;
    
    LFO_INCREMENT(1)  <= to_signed(900, 18);
    LFO_DEPTH(1)      <= to_signed(2**11, 18);
    LFO_ALIGN(1)      <= to_signed(0, 18);
    LFO_WF(1)         <= WF_SINE_I;
    LFO_INCREF(1)     <= 1;
    LFO_PHASEREF(1)   <= 1;
    
    LFO_INCREMENT(2)  <= to_signed(1250, 18);
    LFO_DEPTH(2)      <= to_signed(100, 18);
    LFO_ALIGN(2)      <= to_signed(2**15, 18);
    LFO_WF(2)         <= WF_SQUARE_I;
    LFO_INCREF(2)     <= 2;
    LFO_PHASEREF(2)   <= 2;
    
    LFO_INCREMENT(3)  <= to_signed(1500, 18);
    LFO_DEPTH(3)      <= to_signed(150, 18);
    LFO_ALIGN(3)      <= to_signed(2**10, 18);
    LFO_WF(3)         <= WF_TRI_I;
    LFO_INCREF(3)     <= 3;
    LFO_PHASEREF(3)   <= 3;
    
    LFO_INCREMENT(7)  <= to_signed(1500, 18);
    LFO_DEPTH(7)      <= to_signed(150, 18);
    LFO_ALIGN(7)      <= to_signed(2**10, 18);
    LFO_WF(7)         <= WF_SINE_I;
    LFO_INCREF(7)     <= 7;
    LFO_PHASEREF(7)   <= 7;
    
    LFO_INCREMENT(8)  <= to_signed(2**16, 18);
    LFO_DEPTH(8)      <= to_signed(150, 18);
    LFO_ALIGN(8)      <= to_signed(2**10, 18);
    LFO_WF(8)         <= WF_SINE_I;
    LFO_PHASEREF(8)   <= 7;
    LFO_INCREF(8)     <= 8;
    LFO_PHASEREF(8)   <= 8;
 
    LFO_INCREMENT(9)  <= to_signed(2**17, 18);
    LFO_DEPTH(9)      <= to_signed(150, 18);
    LFO_ALIGN(9)      <= to_signed(2**10, 18);
    LFO_WF(9)         <= WF_SINE_I;
    LFO_PHASEREF(9)   <= 7;
    LFO_INCREF(9)     <= 9;
    LFO_PHASEREF(9)   <= 9;
    
    LFO_INCREMENT(10) <= to_signed(2**17 + 2**16, 18);
    LFO_DEPTH(10)     <= to_signed(150, 18);
    LFO_ALIGN(10)     <= to_signed(2**10, 18);
    LFO_WF(10)        <= WF_SINE_I;
    LFO_PHASEREF(10)  <= 7;
    LFO_INCREF(10)    <= 10;
    LFO_PHASEREF(10)  <= 10;
       
    LFO_INCREMENT(15)  <= to_signed(1500, 18);
    LFO_DEPTH(15)      <= to_signed(150, 18);
    LFO_ALIGN(15)      <= to_signed(0, 18);
    LFO_WF(15)         <= WF_SAW_I;
    LFO_INCREF(15)     <= 15;
    LFO_PHASEREF(15)   <= 15;
    
    wait for 20ms;
    
    for lfonum in 0 to lfocount - 1 loop
        LFO_RESET(lfonum)      <= '1';
        wait for clk100_period;
        LFO_RESET(lfonum)      <= '0';
    end loop;
    
    wait;
end process;

END;