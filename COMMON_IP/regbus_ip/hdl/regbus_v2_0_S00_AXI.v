
`timescale 1 ns / 1 ps

module regbus_v2_0_S00_AXI #(
    // Users to add parameters here

    // User parameters ends
    // Do not modify the parameters beyond this line

    // Width of S_AXI data bus
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH = 16
) (
    // Users to add ports here
    output reg [15:0] WRADDR,
    output reg [ 3:0] BYTEEN,
    output reg        WREN,
    output reg [31:0] WDATA,
    output     [15:0] RDADDR,
    output reg        RDEN,
    input      [31:0] RDATA_DISP,
    input      [31:0] RDATA_CAPT,
    input      [31:0] RDATA_DRAW,
    input      [31:0] RDATA_SOUND,
    input      [31:0] RDATA_OPT0,
    input      [31:0] RDATA_OPT1,
    input      [31:0] RDATA_OPT2,
    input      [31:0] RDATA_OPT3,

    // User ports ends
    // Do not modify the ports beyond this line

    // Global Clock Signal
    input wire S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    // Write channel Protection type. This signal indicates the
    // privilege and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_AWPROT,
    // Write address valid. This signal indicates that the master signaling
    // valid write address and control information.
    input wire S_AXI_AWVALID,
    // Write address ready. This signal indicates that the slave is ready
    // to accept an address and associated control signals.
    output wire S_AXI_AWREADY,
    // Write data (issued by master, acceped by Slave)
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
    // valid data. There is one write strobe bit for each eight
    // bits of the write data bus.
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // Write valid. This signal indicates that valid write
    // data and strobes are available.
    input wire S_AXI_WVALID,
    // Write ready. This signal indicates that the slave
    // can accept the write data.
    output wire S_AXI_WREADY,
    // Write response. This signal indicates the status
    // of the write transaction.
    output wire [1 : 0] S_AXI_BRESP,
    // Write response valid. This signal indicates that the channel
    // is signaling a valid write response.
    output wire S_AXI_BVALID,
    // Response ready. This signal indicates that the master
    // can accept a write response.
    input wire S_AXI_BREADY,
    // Read address (issued by master, acceped by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether the
    // transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_ARPROT,
    // Read address valid. This signal indicates that the channel
    // is signaling valid read address and control information.
    input wire S_AXI_ARVALID,
    // Read address ready. This signal indicates that the slave is
    // ready to accept an address and associated control signals.
    output wire S_AXI_ARREADY,
    // Read data (issued by slave)
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    // Read response. This signal indicates the status of the
    // read transfer.
    output wire [1 : 0] S_AXI_RRESP,
    // Read valid. This signal indicates that the channel is
    // signaling the required read data.
    output wire S_AXI_RVALID,
    // Read ready. This signal indicates that the master can
    // accept the read data and response information.
    input wire S_AXI_RREADY
);

  // AXI4LITE signals
  reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
  reg                            axi_awready;
  reg                            axi_wready;
  reg [                   1 : 0] axi_bresp;
  reg                            axi_bvalid;
  reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
  reg                            axi_arready;
  reg [C_S_AXI_DATA_WIDTH-1 : 0] axi_rdata;
  reg [                   1 : 0] axi_rresp;
  reg                            axi_rvalid;

  /* COJT */
  reg                            pre_axi_arready;

  // Example-specific design signals
  // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
  // ADDR_LSB is used for addressing 32/64 bit registers/memories
  // ADDR_LSB = 2 for 32 bits (n downto 2)
  // ADDR_LSB = 3 for 64 bits (n downto 3)
  localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH / 32) + 1;
  localparam integer OPT_MEM_ADDR_BITS = 1;
  //----------------------------------------------
  //-- Signals for user logic register space example
  //------------------------------------------------

  wire                             slv_reg_rden;
  wire                             slv_reg_wren;
  reg     [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
  integer                          byte_index;

  // I/O Connections assignments

  assign S_AXI_AWREADY = axi_awready;
  assign S_AXI_WREADY  = axi_wready;
  assign S_AXI_BRESP   = axi_bresp;
  assign S_AXI_BVALID  = axi_bvalid;
  assign S_AXI_ARREADY = axi_arready;
  assign S_AXI_RDATA   = axi_rdata;
  assign S_AXI_RRESP   = axi_rresp;
  assign S_AXI_RVALID  = axi_rvalid;
  // Implement axi_awready generation
  // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
  // de-asserted when reset is low.

  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_awready <= 1'b0;
    end else begin
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
        // slave is ready to accept write address when
        // there is a valid write address and write data
        // on the write address and data bus. This design
        // expects no outstanding transactions.
        axi_awready <= 1'b1;
      end else begin
        axi_awready <= 1'b0;
      end
    end
  end

  // Implement axi_awaddr latching
  // This process is used to latch the address when both
  // S_AXI_AWVALID and S_AXI_WVALID are valid.

  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_awaddr <= 0;
    end else begin
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
        // Write Address latching
        axi_awaddr <= S_AXI_AWADDR;
      end
    end
  end

  // Implement axi_wready generation
  // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is
  // de-asserted when reset is low.

  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_wready <= 1'b0;
    end else begin
      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID) begin
        // slave is ready to accept write data when
        // there is a valid write address and write data
        // on the write address and data bus. This design
        // expects no outstanding transactions.
        axi_wready <= 1'b1;
      end else begin
        axi_wready <= 1'b0;
      end
    end
  end

  // Implement memory mapped register select and write logic generation
  // The write data is accepted and written to memory mapped registers when
  // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
  // select byte enables of slave registers while writing.
  // These registers are cleared when reset (active low) is applied.
  // Slave register write enable is asserted when valid address and data are available
  // and the slave is ready to accept the write address and write data.
  assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;


  // Implement write response logic generation
  // The write response and response valid signals are asserted by the slave
  // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.
  // This marks the acceptance of address and indicates the status of
  // write transaction.

  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_bvalid <= 0;
      axi_bresp  <= 2'b0;
    end else begin
      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
        // indicates a valid write response is available
        axi_bvalid <= 1'b1;
        axi_bresp  <= 2'b0;  // 'OKAY' response
      end                   // work error responses in future
          else
            begin
        if (S_AXI_BREADY && axi_bvalid)
                //check if bready is asserted while bvalid is high)
                //(there is a possibility that bready is always asserted high)
                begin
          axi_bvalid <= 1'b0;
        end
      end
    end
  end

  // Implement axi_arready generation
  // axi_arready is asserted for one S_AXI_ACLK clock cycle when
  // S_AXI_ARVALID is asserted. axi_awready is
  // de-asserted when reset (active low) is asserted.
  // The read address is also latched when S_AXI_ARVALID is
  // asserted. axi_araddr is reset to zero on reset assertion.

  /* pre_axi_arreadyはオリジナルのaxi_arreadyと同じ動作 */
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) pre_axi_arready <= 1'b0;
    else begin
      if (~pre_axi_arready && S_AXI_ARVALID) pre_axi_arready <= 1'b1;
      else pre_axi_arready <= 1'b0;
    end
  end

  // make axi_arready by delaying 1-clock pre_axi_arready
  // note: this will cause 1-clock delay for all related signals
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) axi_arready <= 1'b0;
    else axi_arready <= pre_axi_arready;
  end

  // separate axi_araddr only
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) axi_araddr <= 32'b0;
    else if (~axi_arready && S_AXI_ARVALID) axi_araddr <= S_AXI_ARADDR;
  end

  // Implement axi_arvalid generation
  // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_ARVALID and axi_arready are asserted. The slave registers
  // data are available on the axi_rdata bus at this instance. The
  // assertion of axi_rvalid marks the validity of read data on the
  // bus and axi_rresp indicates the status of read transaction.axi_rvalid
  // is deasserted on reset (active low). axi_rresp and axi_rdata are
  // cleared to zero on reset (active low).
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_rvalid <= 0;
      axi_rresp  <= 0;
    end else begin
      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
        // Valid read data is available at the read data bus
        axi_rvalid <= 1'b1;
        axi_rresp  <= 2'b0;  // 'OKAY' response
      end else if (axi_rvalid && S_AXI_RREADY) begin
        // Read data is accepted by the master
        axi_rvalid <= 1'b0;
      end
    end
  end

  // Implement memory mapped register select and read logic generation
  // Slave register read enable is asserted when valid address is available
  // and the slave is ready to accept the read address.
  assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
  always @(*) begin
    // Address decoding for reading registers
    case (axi_araddr[15:12])
      4'h0:    reg_data_out <= RDATA_DISP;
      4'h1:    reg_data_out <= RDATA_CAPT;
      4'h2:    reg_data_out <= RDATA_DRAW;
      4'h3:    reg_data_out <= RDATA_SOUND;
      4'h4:    reg_data_out <= RDATA_OPT0;
      4'h5:    reg_data_out <= RDATA_OPT1;
      4'h6:    reg_data_out <= RDATA_OPT2;
      4'h7:    reg_data_out <= RDATA_OPT3;
      default: reg_data_out <= 0;
    endcase
  end

  // Output register or memory read data
  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
      axi_rdata <= 0;
    end else begin
      // When there is a valid read address (S_AXI_ARVALID) with
      // acceptance of read address by the slave (axi_arready),
      // output the read dada
      if (slv_reg_rden) begin
        axi_rdata <= reg_data_out;  // register read data
      end
    end
  end

  // Add user logic here

  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) WRADDR <= 16'h0;
    else WRADDR <= axi_awaddr;
  end

  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) BYTEEN <= 4'h0;
    else BYTEEN <= S_AXI_WSTRB;
  end

  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) WREN <= 1'b0;
    else WREN <= slv_reg_wren;
  end

  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) WDATA <= 32'h0;
    else WDATA <= S_AXI_WDATA;
  end


  assign RDADDR = axi_araddr;

  always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) RDEN <= 1'b0;
    else if (S_AXI_ARVALID & ~axi_arready) RDEN <= 1'b1;
    else if (axi_arready) RDEN <= 1'b0;
  end

  // User logic ends

endmodule
