VERYL = veryl
VIVADO = vivado

.PHONY: build project clean

build:
	$(VERYL) build

project:
	$(VIVADO) -mode batch -source scripts/project.tcl -nolog -nojournal

bitstream:
	$(VIVADO) -mode batch -source scripts/generate_bitstream.tcl \
		-tclargs ./project/pynq_pattern.xpr 8 \
		-nolog -nojournal

clean:
	$(VERYL) clean
	rm -rf project .Xil *.jou *.log
