library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity nine_input_median is
    generic (
        G_PIXEL_WIDTH : positive := 8
    );
    Port (
        clk          : in  STD_LOGIC;
        rst          : in  STD_LOGIC;
        pixel_in     : in  STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        pixel_valid  : in  STD_LOGIC;
        pixel_ready  : out STD_LOGIC;
        median_out   : out STD_LOGIC_VECTOR(G_PIXEL_WIDTH-1 downto 0);
        median_valid : out STD_LOGIC
    );
end nine_input_median;

architecture Behavioral of nine_input_median is

    type state_t is (S_COLLECT, S_SORT);
    type pixel_array_t is array (0 to 8) of unsigned(G_PIXEL_WIDTH-1 downto 0);

    signal state : state_t := S_COLLECT;

    signal median_array : pixel_array_t := (
        others => (others => '0')
    );

    signal collect_count : integer range 0 to 8 := 0;
    signal sort_pass     : integer range 0 to 7 := 0;
    signal sort_index    : integer range 0 to 7 := 0;

begin

    -- The core accepts pixels only while collecting a 3x3 window.
    pixel_ready <= '1'
        when state = S_COLLECT and rst = '0'
        else '0';

    process(clk)
        variable temp_pixel : unsigned(G_PIXEL_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then

            -- median_valid is intentionally a one-clock pulse.
            median_valid <= '0';

            if rst = '1' then
                state         <= S_COLLECT;
                collect_count <= 0;
                sort_pass     <= 0;
                sort_index    <= 0;
                median_array  <= (others => (others => '0'));
                median_out    <= (others => '0');
                median_valid  <= '0';

            else
                case state is

                    when S_COLLECT =>
                        if pixel_valid = '1' then
                            median_array(collect_count) <= unsigned(pixel_in);

                            if collect_count = 8 then
                                collect_count <= 0;
                                sort_pass     <= 0;
                                sort_index    <= 0;
                                state         <= S_SORT;
                            else
                                collect_count <= collect_count + 1;
                            end if;
                        end if;

                    when S_SORT =>
                        -- One adjacent bubble-sort comparison is performed
                        -- per clock. Eight full passes are sufficient for
                        -- nine elements.
                        if median_array(sort_index) > median_array(sort_index + 1) then
                            temp_pixel := median_array(sort_index);
                            median_array(sort_index)     <= median_array(sort_index + 1);
                            median_array(sort_index + 1) <= temp_pixel;
                        end if;

                        if sort_index = 7 then
                            sort_index <= 0;

                            if sort_pass = 7 then
                                -- The final comparison is between elements
                                -- 7 and 8, so element 4 is already the final
                                -- median value on this clock edge.
                                median_out   <= std_logic_vector(median_array(4));
                                median_valid <= '1';
                                sort_pass    <= 0;
                                state        <= S_COLLECT;
                            else
                                sort_pass <= sort_pass + 1;
                            end if;

                        else
                            sort_index <= sort_index + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
