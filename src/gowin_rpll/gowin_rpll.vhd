library ieee;
use ieee.std_logic_1164.all;

entity gowin_rpll is
  port (
    clkout  : out std_logic;
    clkoutp : out std_logic;
    clkin   : in  std_logic
  );
end entity;

architecture rtl of gowin_rpll is
  signal lock_o, clkoutd_o, clkoutd3_o : std_logic;

  component rPLL
    generic (
      FCLKIN          : string;
      DYN_IDIV_SEL    : string;
      IDIV_SEL        : integer;
      DYN_FBDIV_SEL   : string;
      FBDIV_SEL       : integer;
      DYN_ODIV_SEL    : string;
      ODIV_SEL        : integer;
      PSDA_SEL        : string;
      DYN_DA_EN       : string;
      DUTYDA_SEL      : string;
      CLKOUT_FT_DIR   : bit;
      CLKOUTP_FT_DIR  : bit;
      CLKOUT_DLY_STEP : integer;
      CLKOUTP_DLY_STEP: integer;
      CLKFB_SEL       : string;
      CLKOUT_BYPASS   : string;
      CLKOUTP_BYPASS  : string;
      CLKOUTD_BYPASS  : string;
      DYN_SDIV_SEL    : integer;
      CLKOUTD_SRC     : string;
      CLKOUTD3_SRC    : string;
      DEVICE          : string
    );
    port (
      CLKOUT   : out std_logic;
      LOCK     : out std_logic;
      CLKOUTP  : out std_logic;
      CLKOUTD  : out std_logic;
      CLKOUTD3 : out std_logic;
      RESET    : in  std_logic;
      RESET_P  : in  std_logic;
      CLKIN    : in  std_logic;
      CLKFB    : in  std_logic;
      FBDSEL   : in  std_logic_vector(5 downto 0);
      IDSEL    : in  std_logic_vector(5 downto 0);
      ODSEL    : in  std_logic_vector(5 downto 0);
      PSDA     : in  std_logic_vector(3 downto 0);
      DUTYDA   : in  std_logic_vector(3 downto 0);
      FDLY     : in  std_logic_vector(3 downto 0)
    );
  end component;
begin
  rpll_inst : rPLL
    generic map (
      FCLKIN => "27",
      DYN_IDIV_SEL => "false",
      FBDIV_SEL => 2,
      IDIV_SEL => 0,
      ODIV_SEL => 8,
      DYN_FBDIV_SEL => "false",
      DYN_ODIV_SEL => "false",
      PSDA_SEL => "0100",
      DYN_DA_EN => "false",
      DUTYDA_SEL => "1000",
      CLKOUT_FT_DIR => '1',
      CLKOUTP_FT_DIR => '1',
      CLKOUT_DLY_STEP => 0,
      CLKOUTP_DLY_STEP => 0,
      CLKFB_SEL => "internal",
      CLKOUT_BYPASS => "false",
      CLKOUTP_BYPASS => "false",
      CLKOUTD_BYPASS => "false",
      DYN_SDIV_SEL => 2,
      CLKOUTD_SRC => "CLKOUT",
      CLKOUTD3_SRC => "CLKOUT",
      DEVICE => "GW1NR-9C"
    )
    port map (
      CLKOUT => clkout,
      LOCK => lock_o,
      CLKOUTP => clkoutp,
      CLKOUTD => clkoutd_o,
      CLKOUTD3 => clkoutd3_o,
      RESET => '0',
      RESET_P => '0',
      CLKIN => clkin,
      CLKFB => '0',
      FBDSEL => (others => '0'),
      IDSEL => (others => '0'),
      ODSEL => (others => '0'),
      PSDA => (others => '0'),
      DUTYDA => (others => '0'),
      FDLY => (others => '1')
    );
end architecture;
