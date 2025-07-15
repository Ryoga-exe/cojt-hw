VERYL = veryl
VIVADO = vivado

.PHONY: build project simulation bitstream clean

build:
	$(VERYL) build
	mkdir -p target/disp_ip/src
	mkdir -p target/disp_ip/xgui
	mkdir -p target/disp_ip/hdl
	cp src/disp_ip/component.xml target/disp_ip/
	cp -a src/disp_ip/src/. target/disp_ip/src/
	cp -a src/disp_ip/xgui/. target/disp_ip/xgui/
	cp src/disp_ip/hdl/*.v target/disp_ip/hdl/
	cp src/disp_ip/hdl/*.sv target/disp_ip/hdl/

project:
	$(VIVADO) -mode batch -source scripts/project.tcl -nolog -nojournal

simulation:
	$(VIVADO) -mode batch -source scripts/simulation.tcl -nolog -nojournal

bitstream:
	$(VIVADO) -mode batch -source scripts/generate_bitstream.tcl \
		-tclargs ./project/pynq_display.xpr 8 \
		-nolog -nojournal

clean:
	$(VERYL) clean
	rm -rf target
	rm -rf project .Xil *.jou *.log
	rm -rf simulation
