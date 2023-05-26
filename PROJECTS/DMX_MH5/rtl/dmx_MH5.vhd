library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity dmx_MH5 is
  generic(
    canal_MH5  : positive := 33;         --33
    T_bit      : real     := 4.0E-6;--5.0E-9;    -- 4 us
    f_clk      : real     := 100.0E6    -- 100 MHz
  );
  port (
    btnc     : in  std_logic; -- initialisation asynchrone
    btnu     : in  std_logic; -- pour demarrer la comm DMX
    btnd     : in  std_logic; -- pour configurer un canal du MH5
    sw       : in  std_logic_vector(15 downto 0);  -- sw(15:12) : n°canal -1
                                                   -- sw(7:0)   : valeur binaire du canal
    clk      : in  std_logic;
    ready    : out std_logic;
    -- afficheurs 7 segments
    seg      : out std_logic_vector(6 downto 0);
    dp       : out std_logic;
    an       : out std_logic_vector(3 downto 0);
    -- dmx JB
    tx       : out std_logic;
    set1     : out std_logic;
    rx       : in  std_logic
  );
end entity;

architecture rtl of dmx_MH5 is  
	constant T1  : real := 22.0*T_bit; 
	constant T2  : real := 2.0*T_bit; 
	constant f_baud : real := 1.0/T_bit;
	constant X1: natural := integer(ceil(f_clk*T1));
	constant X2: natural := integer(ceil(f_clk*T2));
	signal ctr_tempo : natural range 0 to X1-1;
	signal addr,resultat : std_logic_vector(8 downto 0);
	signal end_T1, end_T2, end_channel, start_uart,ready_tx,tx_uart, resetn,cmd_tempo, cmd_data,cmd_addr, cmd_ready,cmd_startuart,rise_btnd,btnd1,btnd2,btnd3 :std_logic;
        signal cmd_tx : std_logic_vector(1 downto 0);
	signal data, data_uart,data_mh5_a,data_mh5_b: std_logic_vector(7 downto 0);
	type state is (idle, break,mark,start0,start1,data0,data1);
	signal current_state : state;
	signal next_state    : state;
	signal addr_b : std_logic_vector(3 downto 0);
	signal hexa2 : std_logic_vector(3 downto 0) := "0000";
begin
resetn <= not btnc; 
end_T1 <= '1' when ctr_tempo >=(X1-1) else '0';
end_T2 <= '1' when ctr_tempo >=(X2-1) else '0';
resultat <= std_logic_vector(unsigned(addr)-(canal_MH5-1));
addr_b<=resultat(3 downto 0);
set1<='1';        
tx<='0' when cmd_tx="00" else
    '1' when cmd_tx="01" else
    tx_uart;
ready <= '0' when cmd_ready='0' else
	 '1';
start_uart<= '0' when cmd_startuart='0' else
	     '1';
end_channel<= '1' when addr="000000000" else '0';


data<=data_mh5_b when unsigned(addr) <= ((canal_MH5-1)+15) and unsigned(addr) >= (canal_MH5-1) else (others=>'0');
data_uart <= data when cmd_data='1' else (others=>'0');

--PROCESS
--process FRONT MONTANT BTND
process(clk,resetn) is
begin
    if resetn = '0' then
      btnd1<='1';
      btnd2<='1';
      rise_btnd<='0';
    elsif rising_edge(clk) then
      btnd1<=btnd;
      btnd2<=btnd1;
      rise_btnd<=btnd1 and  not btnd2;
    end if;
end process;
--process STATE
process(clk,resetn) is 
begin
    if resetn = '0' then
      current_state <= idle;
    elsif rising_edge(clk) then
      current_state <= next_state;
    end if;
 end process;
 
--process tempo 
process(clk,resetn) is  
  begin
    if resetn = '0' then
      ctr_tempo    <= 0;
    elsif rising_edge(clk) then
      if cmd_tempo = '1' then
         ctr_tempo <= ctr_tempo+1;
      elsif ctr_tempo >=99 then
         ctr_tempo <= 0;
      else
   	 ctr_tempo <= 0;
      end if;
    end if;  
end process;
-- process addr
process(clk,resetn) is 
  begin
    if resetn = '0' then
      addr    <= (others=>'0');
    elsif rising_edge(clk) then
      if cmd_addr='1' then
        addr <= std_logic_vector(unsigned(addr) +1);
      else
        addr<=addr;
      end if;  
    end if;  
end process; 
--process graphe d'état
process(current_state,end_T1,end_T2,ready_tx,end_channel,btnu) is
begin
    cmd_tempo<='0';
    next_state<=current_state;
    cmd_startuart<='0';
    cmd_data<='0';
    cmd_tx<="01";
    cmd_ready<='1';
    cmd_addr<='0';

    case current_state is
    when idle =>
      if(btnu='1') then
        next_state<=break;
      end if;
      
    when break =>
      if(end_T1='1') then
	 next_state<=mark;
	 cmd_tempo <= '0';
      else
	 cmd_tempo <= '1';
      end if;
      cmd_ready<='0';
      cmd_tx<="00";
      cmd_data<='0';

    when mark =>
      if(end_T2='1') then
	 next_state<=start0;
	 cmd_tempo <= '0';
      else
	 cmd_tempo <= '1';
      end if;
      cmd_tx<="01";
      cmd_ready<='0';
      cmd_data<='0';

    when start0 =>
      if(ready_tx='0') then
        next_state<=start1;
      end if;
      cmd_tx<="11";
      cmd_startuart<='1';
      cmd_tempo<='0';
      cmd_ready<='0';
      cmd_data<='0';
      
    when start1 =>
      if(ready_tx='1') then
        next_state<=data0;
      end if;
      cmd_startuart<='0';
      cmd_data<='1';
      cmd_tx<="11";
      cmd_ready<='0';
      
    when data0 =>
      if(ready_tx='0') then
        next_state<=data1;
        cmd_addr<='1';
      else
	cmd_addr<='0';
      end if;
      cmd_startuart<='1';
      cmd_data<='1';
      cmd_tx<="11";
      cmd_ready<='0';
      cmd_data<='1';

    when data1 =>
      if(ready_tx='1') then
        if(end_channel='1') then
          next_state<=break;
        elsif(end_channel='0') then
          next_state<=data0;
	else 
 	  next_state<=current_state;
        end if;
      end if;  
      cmd_startuart<='0';
      cmd_addr<='0';
      cmd_data<='1';
      cmd_tx<="11";
      cmd_ready<='0';
    end  case;
 end process;
 
LEDUALPORT_TX : entity work.dual_port_ram_mh5
	port map(
	clk=>clk,
	we_a => rise_btnd, 
        di_a => sw(7 downto 0),  
        do_a  => data_mh5_a, 
        addr_a =>sw(15 downto 12),
        addr_b =>addr_b,
        do_b =>data_mh5_b
        ); 
        
LEHEXA_TX : entity work.hexa_display_controller
	generic map
    	(
      	f_clk => f_clk,
      	f_scan => 100.0
      	)
	port map(
	clk=>clk,
	resetn=>resetn,
	en => "1111",
	dot_point => "1111",
	hexa0 => data_mh5_a(3 downto 0),
	hexa1 => data_mh5_a(7 downto 4),
	hexa2 => hexa2,
	hexa3 => sw(15 downto 12),
	seg => seg,
	dp => dp,
	an =>an	
	);
LEUART_TX : entity work.uart_tx
	generic map
    (
      f_clk => f_clk,
      f_baud => 1.0/T_bit,
      N => 8
    )
        port map(
            resetn=>resetn,
            clk=>clk,
            data=>data_uart,
            start=>start_uart,
            ready=>ready_tx,
            tx=>tx_uart
             );
end architecture;

