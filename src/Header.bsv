import Constants::*;

function Bit#(24) encodeHeader(DataRate rate, Length length);
  Bit#(1) parity = 0;

  for (Integer i=0; i < 4; i = i + 1) parity = parity ^ pack(rate)[i];
  for (Integer i=0; i < 12; i = i + 1) parity = parity ^ length[i];

  return {6'b0, parity, length, 1'b0, pack(rate)};
endfunction

function Maybe#(Tuple2#(DataRate, Length)) decodeHeader(Bit#(24) header);
  DataRate rate = unpack(header[3:0]);
  Length length = header[16:5];
  Bit#(6) tail = header[23:18];
  Bit#(1) parity = header[17];
  Bit#(1) zero = header[4];

  for (Integer i=0; i < 4; i = i + 1) parity = parity ^ pack(rate)[i];
  for (Integer i=0; i < 12; i = i + 1) parity = parity ^ length[i];

  if (tail != 0 || zero != 0 || parity != 0) return Invalid;
  else return Valid(tuple2(rate, length));
endfunction
