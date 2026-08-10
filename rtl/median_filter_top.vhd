library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity median_filter_top is
    generic (
        G_IMAGE_WIDTH  : integer := 130;
        G_IMAGE_HEIGHT : integer := 130;
        G_PIXEL_WIDTH  : integer := 8
    );
    Port (
        clk          : in  STD_LOGIC;
        rst          : in  STD_LOGIC;
        pixel_in     : in  STD_LOGIC_VECTOR(7 downto 0);
        pixel_valid  : in  STD_LOGIC;
        pixel_ready  : out STD_LOGIC;
        median_out   : out STD_LOGIC_VECTOR(7 downto 0);
        median_valid : out STD_LOGIC
    );
end median_filter_top;

architecture Behavioral of median_filter_top is

    signal window_0_s : STD_LOGIC_VECTOR(7 downto 0);
    signal window_1_s : STD_LOGIC_VECTOR(7 downto 0);
    signal window_2_s : STD_LOGIC_VECTOR(7 downto 0);
    signal window_3_s : STD_LOGIC_VECTOR(7 downto 0);
    signal window_4_s : STD_LOGIC_VECTOR(7 downto 0);
    signal window_5_s : STD_LOGIC_VECTOR(7 downto 0);
    signal window_6_s : STD_LOGIC_VECTOR(7 downto 0);
    signal window_7_s : STD_LOGIC_VECTOR(7 downto 0);
    signal window_8_s : STD_LOGIC_VECTOR(7 downto 0);

    signal window_valid_s : STD_LOGIC;
    signal window_ready_s : STD_LOGIC;

begin

    U_WINDOW_GENERATOR : entity work.window_3x3
        generic map (
            G_IMAGE_WIDTH  => G_IMAGE_WIDTH,
            G_IMAGE_HEIGHT => G_IMAGE_HEIGHT,
            G_PIXEL_WIDTH  => G_PIXEL_WIDTH
        )
        port map (
            clk          => clk,
            rst          => rst,
            pixel_in     => pixel_in,
            pixel_valid  => pixel_valid,
            pixel_ready  => pixel_ready,
            window_ready => window_ready_s,
            window_0     => window_0_s,
            window_1     => window_1_s,
            window_2     => window_2_s,
            window_3     => window_3_s,
            window_4     => window_4_s,
            window_5     => window_5_s,
            window_6     => window_6_s,
            window_7     => window_7_s,
            window_8     => window_8_s,
            window_valid => window_valid_s
        );

    U_WINDOW_MEDIAN : entity work.windowmedian_unit
        port map (
            clk          => clk,
            rst          => rst,
            window_0     => window_0_s,
            window_1     => window_1_s,
            window_2     => window_2_s,
            window_3     => window_3_s,
            window_4     => window_4_s,
            window_5     => window_5_s,
            window_6     => window_6_s,
            window_7     => window_7_s,
            window_8     => window_8_s,
            window_valid => window_valid_s,
            window_ready => window_ready_s,
            median_out   => median_out,
            median_valid => median_valid
        );

end Behavioral;
