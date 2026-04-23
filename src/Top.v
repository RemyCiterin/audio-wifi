
module top (
  input CLK,
  input RST_N,

  output [7:0] led,
  output ftdi_rxd,
  input ftdi_txd,

);

  mkSoc soc(
    .CLK(CLK),
    .RST_N(RST_N),
    .led(led),
    .btn(ftdi_txd)
  );

endmodule
