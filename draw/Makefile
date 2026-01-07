VERYL = veryl
VIVADO = vivado

IP = draw_ip

ifeq ($(OS),Windows_NT)
	# required bmatzelle.Gow
  MKDIR := mkdir.exe
	CP    := cp.exe
	CPDIR := $(CP) -r
	NPROCS = $(shell echo %NUMBER_OF_PROCESSORS%)
else
  MKDIR := mkdir
	CP    := cp
	CPDIR := $(CP) -a
	NPROCS = $(shell grep -c 'processor' /proc/cpuinfo)
endif

.PHONY: build
build:
	$(VERYL) build
	$(MKDIR) -p target/$(IP)/src
	$(MKDIR) -p target/$(IP)/xgui
	$(MKDIR) -p target/$(IP)/hdl
	$(CP)    src/$(IP)/component.xml target/$(IP)/
	$(CPDIR) src/$(IP)/src/. target/$(IP)/src/
	$(CPDIR) src/$(IP)/xgui/. target/$(IP)/xgui/
	$(CP)    src/$(IP)/hdl/*.v target/$(IP)/hdl/

.PHONY: project
project:
	$(VIVADO) -mode batch -source scripts/project.tcl -nolog -nojournal

.PHONY: simulation
simulation:
	@test -f src/sim/tb/axi_vip_axi4pc.sv || (echo "Error: axi_vip_axi4pc.sv does not exist."; exit 1)
	@echo "OK: axi_vip_axi4pc.sv exists."
	$(VIVADO) -mode batch -source scripts/simulation.tcl -nolog -nojournal

.PHONY: bitstream
bitstream:
	$(VIVADO) -mode batch -source scripts/generate_bitstream.tcl \
		-tclargs ./project/pynq_display.xpr $(NPROCS) \
		-nolog -nojournal

.PHONY: clean
clean:
	$(VERYL) clean
	rm -rf target
	rm -rf project .Xil *.jou *.log
	rm -rf simulation
