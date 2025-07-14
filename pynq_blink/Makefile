VIVADO = vivado

.PHONY: project bitstream clean

project:
	$(VIVADO) -mode batch -source scripts/project.tcl -nolog -nojournal

bitstream:
	$(VIVADO) -mode batch -source scripts/generate_bitstream.tcl \
		-tclargs ./project/pynq_blink.xpr 8 \
		-nolog -nojournal

clean:
	rm -rf project .Xil *.jou *.log
