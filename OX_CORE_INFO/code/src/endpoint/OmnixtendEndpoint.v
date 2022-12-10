//Placeholder Module

module OmnixtendEndpoint(
    sconfig_axi_aclk,
	sconfig_axi_aresetn,
	sconfig_axi_arready,
	sconfig_axi_arvalid,
	sconfig_axi_araddr,
	sconfig_axi_arprot,
	sconfig_axi_rvalid,
	sconfig_axi_rready,
	sconfig_axi_rdata,
	sconfig_axi_rresp,
	sconfig_axi_awready,
	sconfig_axi_awvalid,
	sconfig_axi_awaddr,
	sconfig_axi_awprot,
	sconfig_axi_wready,
	sconfig_axi_wvalid,
	sconfig_axi_wdata,
	sconfig_axi_wstrb,
	sconfig_axi_bvalid,
	sconfig_axi_bready,
	sconfig_axi_bresp,

	interrupt,

	sfp_axis_tx_aclk_0,
	sfp_axis_tx_aresetn_0,
	sfp_axis_tx_0_tvalid,
	sfp_axis_tx_0_tready,
	sfp_axis_tx_0_tdata,
	sfp_axis_tx_0_tlast,
	sfp_axis_tx_0_tkeep,
	sfp_axis_tx_0_tDest,

    sfp_axis_rx_aclk_0,
	sfp_axis_rx_aresetn_0,
	sfp_axis_rx_0_tready,
	sfp_axis_rx_0_tvalid,
	sfp_axis_rx_0_tdata,
	sfp_axis_rx_0_tkeep,
	sfp_axis_rx_0_tDest,
	sfp_axis_rx_0_tlast
);
  input  sfp_axis_rx_aclk_0;
  input  sfp_axis_rx_aresetn_0;
  input  sfp_axis_tx_aclk_0;
  input  sfp_axis_tx_aresetn_0;
  input  sconfig_axi_aclk;
  input  sconfig_axi_aresetn;

  output sconfig_axi_arready;
  input  sconfig_axi_arvalid;
  input  [15 : 0] sconfig_axi_araddr;
  input  [2 : 0] sconfig_axi_arprot;
  output sconfig_axi_rvalid;
  input  sconfig_axi_rready;
  output [63 : 0] sconfig_axi_rdata;
  output [1 : 0] sconfig_axi_rresp;
  output sconfig_axi_awready;
  input  sconfig_axi_awvalid;
  input  [15 : 0] sconfig_axi_awaddr;
  input  [2 : 0] sconfig_axi_awprot;
  output sconfig_axi_wready;
  input  sconfig_axi_wvalid;
  input  [63 : 0] sconfig_axi_wdata;
  input  [7 : 0] sconfig_axi_wstrb;
  output sconfig_axi_bvalid;
  input  sconfig_axi_bready;
  output [1 : 0] sconfig_axi_bresp;

  output interrupt;

  output sfp_axis_tx_0_tvalid;
  input  sfp_axis_tx_0_tready;
  output [63 : 0] sfp_axis_tx_0_tdata;
  output sfp_axis_tx_0_tlast;
  output [7 : 0] sfp_axis_tx_0_tkeep;
  output [3 : 0] sfp_axis_tx_0_tDest;

  output sfp_axis_rx_0_tready;
  input  sfp_axis_rx_0_tvalid;
  input  [63 : 0] sfp_axis_rx_0_tdata;
  input  [7 : 0] sfp_axis_rx_0_tkeep;
  input  [3 : 0] sfp_axis_rx_0_tDest;
  input  sfp_axis_rx_0_tlast;

endmodule

