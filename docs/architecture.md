# Architecture Notes

The design implements a 3×3 grayscale median filter as a backpressured VHDL stream.

## 1. Data flow

```text
pixel stream
    │
    ▼
window_3x3
    │  nine parallel pixels
    ▼
paralel_to_series_converter
    │  one pixel per accepted clock
    ▼
nine_input_median
    │
    ▼
median_out + median_valid
```

For the full image demonstration, MATLAB creates a 128×128 noisy grayscale image, applies one-pixel replicate padding, and produces a 130×130 row-major input stream. The hardware therefore receives 16,900 input pixels and generates 16,384 valid 3×3 windows.

## 2. Why two line buffers are enough

A 3×3 window centered on the current processing position needs three image rows:

```text
row i-2   ← stored in line_buffer2
row i-1   ← stored in line_buffer1
row i     ← current incoming stream
```

The current row does not need a third full line buffer because its pixels are already arriving through `pixel_in`. Three shift registers per row preserve the most recent three columns.

At column `c`, the window registers represent columns `c-2`, `c-1`, and `c` after the accepted input edge.

## 3. Window validity

The row and column counters are zero-based. A complete 3×3 neighborhood first exists at:

```text
row_count    = 2
column_count = 2
```

Therefore the valid positions for a 130×130 padded stream are:

```text
rows    2 ... 129  → 128 rows
columns 2 ... 129  → 128 columns
```

Total output windows:

```text
128 × 128 = 16,384
```

The first two rows and first two columns are consumed normally but do not assert `window_valid`.

## 4. Line-buffer reset decision

The line-buffer memories are not fully reset.

This is safe because no valid output is produced until row 2. By that point:

- row 0 has already filled `line_buffer1`,
- row 1 has moved row 0 into `line_buffer2`,
- row 1 has replaced `line_buffer1`.

Thus every memory location needed by the first valid window has already been overwritten with known image data.

Avoiding a full memory reset is also more compatible with FPGA RAM inference than resetting every stored pixel.

## 5. Valid/ready protocol

A transfer occurs on a rising clock edge only when both signals are asserted:

```text
transfer = valid AND ready
```

The source owns `valid` and data. The receiver owns `ready`.

If `ready = 0`, the source must keep its current data and `valid` stable. This allows slower blocks to apply backpressure without losing pixels.

The design uses this pattern at three boundaries:

1. input source → `window_3x3`
2. `window_3x3` → `windowmedian_unit`
3. converter → median core

This is conceptually similar to AXI4-Stream handshaking, but the design does not claim to implement the complete AXI4-Stream interface.

## 6. Parallel-to-serial controller

The converter FSM contains three states:

```text
S_WAIT_WINDOW
S_SEND_PIXELS
S_WAIT_MEDIAN
```

### `S_WAIT_WINDOW`

`window_ready = 1`. When `window_valid = 1`, all nine pixels are captured into `window_arr`.

### `S_SEND_PIXELS`

`median_pixel_valid = 1`. The current output is selected by:

```vhdl
median_pixel_in <= window_arr(send_index);
```

`send_index` advances only when `median_pixel_ready = 1`, so the selected pixel remains stable under backpressure.

### `S_WAIT_MEDIAN`

After pixel 8 is accepted, the converter waits for `median_valid`. Using the result-valid signal keeps the controller independent of the internal implementation of the median core.

## 7. Median core

The median core has two main states:

```text
S_COLLECT
S_SORT
```

Nine pixels are first collected into an array. The core then performs one adjacent comparison per clock using bubble sort.

For nine elements:

```text
8 adjacent comparisons per pass
× 8 passes
= 64 sorting clocks
```

The middle sorted element is index 4.

With no stalls, one accepted 3×3 window requires:

```text
1 clock  : converter captures the parallel window
9 clocks : median core collects nine serial pixels
64 clocks: sorting
```

The result is therefore produced about 73 clock periods after the converter captures the window. The exact end-to-end latency from an input pixel also includes the window-generator handshake.

## 8. Throughput trade-off

This architecture is intentionally optimized for readability rather than throughput.

The median unit handles one window at a time, and the window generator keeps at most one pending output window. Therefore backpressure reaches the input stream while the median core is sorting.

This is useful for learning and waveform inspection because every control event is visible, but it is not suitable for a one-pixel-per-clock video pipeline.

A performance-oriented redesign could use:

- a fixed compare-exchange sorting network,
- pipeline registers between comparator stages,
- FIFO buffering between window generation and filtering,
- formal AXI4-Stream interfaces,
- independent input and output flow control.

## 9. Verification hierarchy

Verification is layered so each architectural boundary can be isolated:

```text
tb_nine_input_median
        ↓
tb_window_3x3
        ↓
tb_windowmedian_unit
        ↓
tb_median_filter_top
        ↓
tb_median_filter_file + MATLAB reference
```

The final file-based testbench reads 16,900 input pixels and 16,384 MATLAB reference pixels with `TEXTIO`. Each VHDL median result is compared immediately against the corresponding MATLAB reference value before it is written to `vhdl_output_128.txt`.
