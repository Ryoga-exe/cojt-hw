VERYL = veryl
VIVADO = vivado

ifeq ($(OS),Windows_NT)
	# required bmatzelle.Gow
  MKDIR := mkdir.exe
	CP := cp.exe
else
  MKDIR := mkdir
	CP := cp
endif

.PHONY: build project simulation bitstream clean

build:
	$(VERYL) build
	$(MKDIR) -p target/disp_ip/src
	$(MKDIR) -p target/disp_ip/xgui
	$(MKDIR) -p target/disp_ip/hdl
	$(CP) src/disp_ip/component.xml target/disp_ip/
	$(CP) -a src/disp_ip/src/. target/disp_ip/src/
	$(CP) -a src/disp_ip/xgui/. target/disp_ip/xgui/
	$(CP) src/disp_ip/hdl/*.v target/disp_ip/hdl/
	$(CP) src/disp_ip/hdl/*.sv target/disp_ip/hdl/

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
