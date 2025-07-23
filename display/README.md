# display

[筑波大学情報学群組み込み技術キャンパスOJT (COJT) ハードウェアコース](https://www.cojt.or.jp/tkb/curriculum/index.html#b) 表示回路

Hardware display subsystem for [University of Tsukuba COJT Embedded Systems OJT Hardware Course](https://www.cojt.or.jp/tkb/curriculum/index.html#b) built with Veryl and targeting Ultra96V2.

## Prerequisites

- **Veryl**: Install from https://veryl-lang.org/install
- **Xilinx Vivado** 2024.2 or later
- **Make** utility on your PATH

## Build

Generate SystemVeriog and display ip

```shell
make build
```

## Create a Vivado project

```shell
make project

# Open GUI if desired:
# vivado project/pynq_display.xpr
```

## Create a simulation project

```
make simulation

# Open GUI if desired:
# vivado simulation/sim_display.xpr
```

## Generate FPGA bitstream

Runs synthesis and implementation

```
make bitstream
```

NOTE: do this after `make project`

## Cleaning up

```
make clean
```
