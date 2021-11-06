library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library work;
use work.spectral_pkg.all;

library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;

-- create a 1D control as a function of
-- patch age, note age, 
-- ??? Need better info

entity control_mixer is
generic (
    NOTECOUNT : integer := 128;
    PROCESS_BW : integer := 18;
    CTRL_COUNT : integer := 4
);
port (
    clk               : in STD_LOGIC;
    rst               : in STD_LOGIC;
    
    Z02_PatchAge      : in sfixed;
    Z02_NoteAge       : in sfixed;
    Z02_Index         : in sfixed;
    Z00_addr          : in std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);

    ctrl_scale_wr     : in std_logic_vector(CTRL_COUNT-1 downto 0);
    ctrl_scale_wraddr : in std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);
    ctrl_scale_wrdata : in std_logic_vector(PROCESS_BW - 1 downto 0);

    Z05_sum              : out sfixed(1 downto -PROCESS_BW + 2);
    run           : in std_logic_vector
    );
end control_mixer;

architecture arch_imp of control_mixer is
Constant ADDR_WIDTH : integer := integer(round(log2(real(NOTECOUNT))));
type allctrlscaletype   is array (0 to CTRL_COUNT-1) of std_logic_vector(PROCESS_BW - 1 downto 0);
type allctrlscaletypesf is array (0 to CTRL_COUNT-1) of sfixed(1 downto -PROCESS_BW +2);
signal Z01_Ctrl_scale      : allctrlscaletype;
signal Z02_Ctrl_scaleSf    : allctrlscaletypesf;

signal run_Z09_Z05         : std_logic_vector(4 downto 0);

signal Z03_PatchAge_scaled: sfixed(1 downto -PROCESS_BW + 2);
signal Z03_NoteAge_scaled : sfixed(1 downto -PROCESS_BW + 2);
signal Z03_Index_scaled   : sfixed(1 downto -PROCESS_BW + 2);
signal Z03_Fixed_scaled   : sfixed(1 downto -PROCESS_BW + 2);

signal Z04_intermediate_sum0 : sfixed(1 downto -PROCESS_BW + 2);
signal Z04_intermediate_sum1 : sfixed(1 downto -PROCESS_BW + 2);

signal Z01_addr  : std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);
signal Z02_addr  : std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);
signal Z03_addr  : std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);
signal Z04_addr  : std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);
signal Z05_addr  : std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);

begin

run_Z09_Z05 <= run(Z09 downto Z05);

loop2:
for i in 0 to CTRL_COUNT-1 generate
    
    ctrl_scale : entity work.simple_dual_one_clock
    generic map(
        DATA_WIDTH   => PROCESS_BW, 
        ADDR_WIDTH   => ADDR_WIDTH
        )
    port map(
        clk   => clk  ,
        wren   => ctrl_scale_wr(i),
        rden   => run(Z00)    ,
        wea   => '1'         ,
        wraddr => ctrl_scale_wraddr,
        rdaddr => Z00_addr,
        wrdata   => ctrl_scale_wrdata,
        rddata   => Z01_Ctrl_scale(i)  
    );
    
end generate;


process (clk)
begin
  if rising_edge(clk) then 
    if rst = '0' then
        if run(Z00) = '1' then
            Z01_addr <= Z00_addr;
        end if;
        
        if run(Z01) = '1' then
            Z02_addr <= Z01_addr;
            sfloop:
            for i in 0 to CTRL_COUNT-1 loop
                Z02_Ctrl_scaleSf(i) <= sfixed(Z01_Ctrl_scale(i));
            end loop;
        end if;
        
        if run(Z02) = '1' then
            Z03_addr <= Z02_addr;
            Z03_PatchAge_scaled <= resize(Z02_PatchAge*Z02_Ctrl_scalesf(CTRL_PATCHAGE), Z03_Fixed_scaled, fixed_wrap, fixed_truncate );
            Z03_NoteAge_scaled  <= resize(Z02_NoteAge *Z02_Ctrl_scalesf(CTRL_NOTEAGE), Z03_Fixed_scaled, fixed_wrap, fixed_truncate );
            Z03_Index_scaled    <= resize(Z02_Index   *Z02_Ctrl_scalesf(CTRL_INDEX), Z03_Fixed_scaled, fixed_wrap, fixed_truncate );
            Z03_Fixed_scaled    <= Z02_Ctrl_scalesf(CTRL_FIXED);  
        end if;
        
        if run(Z03) = '1' then
            Z04_addr <= Z03_addr;
            Z04_intermediate_sum0 <= resize(Z03_PatchAge_scaled + Z03_NoteAge_scaled, Z04_intermediate_sum0, fixed_wrap, fixed_truncate );
            Z04_intermediate_sum1 <= resize(Z03_Index_scaled + Z03_Fixed_scaled, Z04_intermediate_sum0, fixed_wrap, fixed_truncate );
        end if;
        
        if run(Z04) = '1' then
            Z05_addr <= Z04_addr;
            Z05_sum <= resize(Z04_intermediate_sum0 + Z04_intermediate_sum1, Z04_intermediate_sum1, fixed_wrap, fixed_truncate );
        end if;
    end if;
  end if;
end process;


end arch_imp;