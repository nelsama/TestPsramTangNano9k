library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx_v2 is
  generic (
    clk_freq  : integer := 27000000;
    uart_freq : integer := 115200
  );
  port (
    clk     : in  std_logic;
    din     : in  std_logic_vector(7 downto 0);
    wr_en   : in  std_logic;
    tx_busy : out std_logic;
    tx_p    : out std_logic
  );
end entity;

architecture rtl of uart_tx_v2 is
  type state_t is (STATE_IDLE, STATE_START, STATE_DATA, STATE_STOP);
  signal state : state_t := STATE_IDLE;

  signal data_reg  : std_logic_vector(7 downto 0) := (others => '0');
  signal bitpos    : unsigned(2 downto 0) := (others => '0');
  constant TX_CLK_MAX : integer := (clk_freq / uart_freq) - 1;
  signal tx_clkcnt : integer range 0 to TX_CLK_MAX := 0;
  signal tx_clk    : std_logic;
  signal tx_reg    : std_logic := '1';
begin
  tx_clk <= '1' when tx_clkcnt = 0 else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      if tx_clkcnt >= TX_CLK_MAX then
        tx_clkcnt <= 0;
      else
        tx_clkcnt <= tx_clkcnt + 1;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      case state is
        when STATE_IDLE =>
          if wr_en = '1' then
            state <= STATE_START;
            data_reg <= din;
            bitpos <= (others => '0');
          end if;

        when STATE_START =>
          if tx_clk = '1' then
            tx_reg <= '0';
            state <= STATE_DATA;
          end if;

        when STATE_DATA =>
          if tx_clk = '1' then
            tx_reg <= data_reg(to_integer(bitpos));
            if bitpos = "111" then
              state <= STATE_STOP;
            else
              bitpos <= bitpos + 1;
            end if;
          end if;

        when STATE_STOP =>
          if tx_clk = '1' then
            tx_reg <= '1';
            state <= STATE_IDLE;
          end if;
      end case;
    end if;
  end process;

  tx_busy <= '1' when state /= STATE_IDLE else '0';
  tx_p <= tx_reg;
end architecture;
