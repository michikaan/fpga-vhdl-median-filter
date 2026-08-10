# Generated test vectors

The MATLAB script generates the text files used by the full-image VHDL testbench.

- `noisy_pixels_padded_130.txt` — 130×130 padded noisy input image, one decimal pixel per line, row-major order: **16,900 values**.
- `reference_pixels_128.txt` — MATLAB 3×3 median-filter reference, one decimal pixel per line, row-major order: **16,384 values**.
- `vhdl_output_128.txt` — written by the VHDL `TEXTIO` testbench: **16,384 values**.

`tb/tb_median_filter_file.vhd` reads both the input and reference files. Every VHDL output pixel is checked against the corresponding MATLAB reference pixel before being written to `vhdl_output_128.txt`.

These are generated artifacts and are intentionally excluded by `.gitignore`.

For Vivado/XSim, make both `noisy_pixels_padded_130.txt` and `reference_pixels_128.txt` visible from the simulator working directory, or edit the file constants at the top of `tb/tb_median_filter_file.vhd`.
