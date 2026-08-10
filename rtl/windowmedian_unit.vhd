library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity windowmedian_unit is
    generic (
        G_PIXEL_WIDTH : positive := 8
    );
    Port (
        clk          : in  STD_LOGIC;
        rst          : in  STD_LOGIC;

        window_0     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_1     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_2     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_3     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_4     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_5     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_6     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_7     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_8     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        window_valid : in  STD_LOGIC;
        window_ready : out STD_LOGIC;

        median_out   : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        median_valid : out STD_LOGIC
    );
end windowmedian_unit;

architecture Behavioral of windowmedian_unit is

    signal median_pixel_in_s    : STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
    signal median_pixel_valid_s : STD_LOGIC;
    signal median_pixel_ready_s : STD_LOGIC;
    signal median_valid_s       : STD_LOGIC;

begin

    median_valid <= median_valid_s;

    U_CONVERTER : entity work.paralel_to_series_converter
        generic map (
            G_PIXEL_WIDTH => G_PIXEL_WIDTH
        )
        port map (
            clk                => clk,
            rst                => rst,
            window_0           => window_0,
            window_1           => window_1,
            window_2           => window_2,
            window_3           => window_3,
            window_4           => window_4,
            window_5           => window_5,
            window_6           => window_6,
            window_7           => window_7,
            window_8           => window_8,
            window_valid       => window_valid,
            window_ready       => window_ready,
            median_pixel_in    => median_pixel_in_s,
            median_pixel_valid => median_pixel_valid_s,
            median_valid       => median_valid_s,
            median_pixel_ready => median_pixel_ready_s
        );

    U_MEDIAN : entity work.nine_input_median
        generic map (
            G_PIXEL_WIDTH => G_PIXEL_WIDTH
        )
        port map (
            clk          => clk,
            rst          => rst,
            pixel_in     => median_pixel_in_s,
            pixel_valid  => median_pixel_valid_s,
            pixel_ready  => median_pixel_ready_s,
            median_out   => median_out,
            median_valid => median_valid_s
        );

end Behavioral;
