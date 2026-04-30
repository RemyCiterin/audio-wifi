import Constants::*;
import Vector::*;

export Interleaver(..);
export DeInterleaver(..);

export mkInterleaver;
export mkDeInterleaver;

interface Interleaver;
  method Action put(DataRate rate, Bit#(48) packet);
  method ActionValue#(Bit#(288)) get;
endinterface

interface DeInterleaver;
  method Action put(DataRate rate, Bit#(288) packet);
  method ActionValue#(Bit#(48)) get;
endinterface

function Integer interleavePermutation(DataRate rate, Integer k);
  Integer bpsc = coded_bits_per_subcarier(rate);
  Integer cbps = coded_bits_per_ofdm(rate);

  Integer s = 1;
  if (bpsc/2 > 1) s = bpsc/2;

  Integer i = (cbps / 16) * (k % 16) + (k / 16);
  Integer j = s * (i / s) + ((i + cbps - ( (16*i) / cbps )) % s);

  return j;
endfunction

(* synthesize *)
module mkInterleaver(Interleaver);

  function Bit#(288) interleave(DataRate rate, Bit#(288) packet);
    Bit#(288) new_packet = 0;
    for (Integer i=0; i < 288; i = i + 1)
      new_packet[interleavePermutation(rate, i)] = packet[i];
    return new_packet;
  endfunction

endmodule

(* synthesize *)
module mkDeInterleaver(DeInterleaver);
  Reg#(Bit#(288)) packet <- mkRegU;
  Reg#(Bit#(2)) state <- mkReg(0);
  Reg#(DataRate) rate <- mkRegU;
  Reg#(Bit#(4)) index <- mkRegU;

  function Bit#(288) deinterleave(DataRate r, Bit#(288) p);
    Bit#(288) new_packet = 0;
    for (Integer i=0; i < 288; i = i + 1)
      new_packet[i] = p[interleavePermutation(r, i)];
    return new_packet;
  endfunction

  rule deinterleave_rl if (state == 1);
    // Use constant rates => permutations are computed at compile time
    if (rate == RATE_6MBPS) packet <= deinterleave(RATE_6MBPS, packet);
    if (rate == RATE_12MBPS) packet <= deinterleave(RATE_12MBPS, packet);
    if (rate == RATE_18MBPS) packet <= deinterleave(RATE_18MBPS, packet);
    if (rate == RATE_24MBPS) packet <= deinterleave(RATE_24MBPS, packet);
    if (rate == RATE_36MBPS) packet <= deinterleave(RATE_36MBPS, packet);
    if (rate == RATE_48MBPS) packet <= deinterleave(RATE_48MBPS, packet);
    if (rate == RATE_54MBPS) packet <= deinterleave(RATE_54MBPS, packet);
    index <= fromInteger(data_bits_per_ofdm(rate) / 24);
    state <= 2;
  endrule

  method Action put(DataRate r, Bit#(288) p) if (state == 0);
    // TODO: compute index
    packet <= p;
    state <= 1;
    rate <= r;
  endmethod

  method ActionValue#(Bit#(48)) get if (state == 2);
    if (puncturing_from_rate(rate) == PUNCTURING_1_2) packet <= packet >> 48;
    if (puncturing_from_rate(rate) == PUNCTURING_2_3) packet <= packet >> 36;
    if (puncturing_from_rate(rate) == PUNCTURING_3_4) packet <= packet >> 32;

    $display("index: ", index);
    if (index == 1) state <= 0;
    index <= index - 1;

    return truncate(packet);
  endmethod
endmodule
