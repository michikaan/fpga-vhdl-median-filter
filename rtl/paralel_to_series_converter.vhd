library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity paralel_to_series_converter is
    Port (
        clk                : in  STD_LOGIC;
        rst                : in  STD_LOGIC;

        window_0           : in  STD_LOGIC_VECTOR(7 downto 0);
        window_1           : in  STD_LOGIC_VECTOR(7 downto 0);
        window_2           : in  STD_LOGIC_VECTOR(7 downto 0);
        window_3           : in  STD_LOGIC_VECTOR(7 downto 0);
        window_4           : in  STD_LOGIC_VECTOR(7 downto 0);
        window_5           : in  STD_LOGIC_VECTOR(7 downto 0);
        window_6           : in  STD_LOGIC_VECTOR(7 downto 0);
        window_7           : in  STD_LOGIC_VECTOR(7 downto 0);
        window_8           : in  STD_LOGIC_VECTOR(7 downto 0);
        window_valid       : in  STD_LOGIC;
        window_ready       : out STD_LOGIC;

        median_pixel_in    : out STD_LOGIC_VECTOR(7 downto 0);
        median_pixel_valid : out STD_LOGIC;
        median_valid       : in  STD_LOGIC;
        median_pixel_ready : in  STD_LOGIC
    );
end paralel_to_series_converter;

architecture Behavioral of paralel_to_series_converter is

    type state_t is (S_WAIT_WINDOW, S_SEND_PIXELS, S_WAIT_MEDIAN);
    type window_array_t is array (0 to 8) of STD_LOGIC_VECTOR(7 downto 0);

    signal state      : state_t := S_WAIT_WINDOW;
    signal window_arr : window_array_t := (others => (others => '0'));
    signal send_index : integer range 0 to 8 := 0;

begin

    window_ready <= '1'
        when state = S_WAIT_WINDOW and rst = '0'
        else '0';

    median_pixel_valid <= '1'
        when state = S_SEND_PIXELS and rst = '0'
        else '0';

    -- Combinational selection keeps the currently addressed pixel stable
    -- before the rising edge on which valid/ready handshaking occurs.
    median_pixel_in <= window_arr(send_index)
        when state = S_SEND_PIXELS and rst = '0'
        else (others => '0');

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state      <= S_WAIT_WINDOW;
                send_index <= 0;
                window_arr <= (others => (others => '0'));

            else
                case state is

                    when S_WAIT_WINDOW =>
                        if window_valid = '1' then
                            window_arr(0) <= window_0;
                            window_arr(1) <= window_1;
                            window_arr(2) <= window_2;
                            window_arr(3) <= window_3;
                            window_arr(4) <= window_4;
                            window_arr(5) <= window_5;
                            window_arr(6) <= window_6;
                            window_arr(7) <= window_7;
                            window_arr(8) <= window_8;

                            send_index <= 0;
                            state      <= S_SEND_PIXELS;
                        end if;

                    when S_SEND_PIXELS =>
                        if median_pixel_ready = '1' then
                            if send_index = 8 then
                                send_index <= 0;
                                state      <= S_WAIT_MEDIAN;
                            else
                                send_index <= send_index + 1;
                            end if;
                        end if;

                    when S_WAIT_MEDIAN =>
                        if median_valid = '1' then
                            state <= S_WAIT_WINDOW;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
