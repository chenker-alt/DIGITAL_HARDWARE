library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_dmx_MH5 is
end entity;

architecture rtl of tb_dmx_MH5 is
constant f_clk  : real := 100.0E6; 
constant T_bit  : real := 50.0E-9; 
constant hp : time := 5 ns;
signal  clk : std_logic := '0';
signal  btnc : std_logic;
signal  btnu : std_logic;
signal  btnd : std_logic;
signal  rx : std_logic:='1';
signal  tx : std_logic;
signal  ready : std_logic;
signal set1 : std_logic; 
signal canal_MH5 : positive:=3;
signal sw : std_logic_vector(15 downto 0);
signal seg : std_logic_vector(6 downto 0);
signal dp : std_logic;
signal an : std_logic_vector(3 downto 0);

begin
  
  clk <= not clk after hp;   
  process  is
  begin
    sw <= "0001000000001100"; 
    btnc <= '1';
    btnu <= '0';
    btnd <= '0';
    wait for 10 ns;
    btnc <= '0';
    wait for 100 ns;
    btnu <= '1';
    wait for 100 ns;
    btnd <= '1';
    wait;
    

  end process;
dut : entity work.dmx_MH5
    generic map (
      canal_MH5 => canal_MH5,
      f_clk => f_clk,
      T_bit => T_bit
    )
    port map (
      clk => clk,
      btnc => btnc,
      btnu => btnu,
      btnd => btnd,
      rx => rx,
      tx => tx,
      ready => ready,
      set1 => set1,
      sw => sw,
      seg => seg,
      dp => dp,
      an => an
    );
end architecture;
