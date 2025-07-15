VERYL = veryl
VIVADO = vivado

.PHONY: build project clean

build:
	$(VERYL) build
	mkdir -p target/disp_ip/src
	mkdir -p target/disp_ip/xgui
	cp -a src/disp_ip/src/. target/disp_ip/src/
	cp -a src/disp_ip/xgui/. target/disp_ip/xgui/

project:
	$(VIVADO) -mode batch -source scripts/project.tcl -nolog -nojournal

bitstream:
	$(VIVADO) -mode batch -source scripts/generate_bitstream.tcl \
		-tclargs ./project/pynq_pattern.xpr 8 \
		-nolog -nojournal

clean:
	$(VERYL) clean
	rm -rf target
	rm -rf project .Xil *.jou *.log
