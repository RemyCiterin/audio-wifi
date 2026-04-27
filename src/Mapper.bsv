import FixedPoint::*;
import Constants::*;
import Complex::*;
import Vector::*;
import Real::*;

///////////////////////////////////////////////////////////////////////////////////////////////////
// Map one bit into a BPSK endoded carrier:
// see table 82 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
///////////////////////////////////////////////////////////////////////////////////////////////////
function Cmplx get_bpsk_value(Bit#(1) x);
  Fxpt i = case (x) matches
    'b0 : -1;
    'b1 : 1;
  endcase;

  Fxpt q = 0;

  return cmplx(i, q);
endfunction

///////////////////////////////////////////////////////////////////////////////////////////////////
// Map two bits into a QPSK endoded carrier:
// see table 83 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
///////////////////////////////////////////////////////////////////////////////////////////////////
function Cmplx get_qpsk_value(Bit#(2) x);
  // warning: the original table look at the bits in reverse order
  function Fxpt toFxpt(Bit#(1) b);
    return case (b) matches
    'b0 : -fromReal(1/sqrt(2));
    'b1 : fromReal(1/sqrt(2));
    endcase;
  endfunction

  return cmplx(toFxpt(x[0]), toFxpt(x[1]));
endfunction

///////////////////////////////////////////////////////////////////////////////////////////////////
// Map four bits into a 16-QAM endoded carrier:
// see table 84 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
///////////////////////////////////////////////////////////////////////////////////////////////////
function Cmplx get_qam16_value(Bit#(4) x);
  // warning: the original table look at the bits in reverse order
  function Fxpt toFxpt(Bit#(2) b);
    return case (b) matches
      2'b00 : -fromReal(3/sqrt(10));
      2'b01 : fromReal(3/sqrt(10));
      2'b10 : -fromReal(1/sqrt(10));
      2'b11 : fromReal(1/sqrt(10));
    endcase;
  endfunction

  return cmplx(toFxpt(x[1:0]), toFxpt(x[3:2]));
endfunction

///////////////////////////////////////////////////////////////////////////////////////////////////
// Map six bits into a 64-QAM endoded carrier:
// see table 84 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
///////////////////////////////////////////////////////////////////////////////////////////////////
function Cmplx get_qam64_value(Bit#(6) x);
  // warning: the original table look at the bits in reverse order
  function Fxpt toFxpt(Bit#(3) b);
    return case (b) matches
      3'b000 : -fromReal(7/sqrt(42));
      3'b001 : fromReal(7/sqrt(42));
      3'b010 : -fromReal(1/sqrt(42));
      3'b011 : fromReal(1/sqrt(42));
      3'b100 : -fromReal(5/sqrt(42));
      3'b101 : fromReal(5/sqrt(42));
      3'b110 : -fromReal(3/sqrt(42));
      3'b111 : fromReal(3/sqrt(42));
    endcase;
  endfunction

  return cmplx(toFxpt(x[2:0]), toFxpt(x[5:3]));
endfunction

interface Mapper;
  method Action put(Maybe#(DataRate) rate, Bit#(288) packet);
  method ActionValue#(Symbol) get();
endinterface

///////////////////////////////////////////////////////////////////////////////////////////////////
// Map packets of up-to 288 bits into a given rate and insert the pilots:
//  - if the rate is None, we reuse the rate of the previous packet
//  - otherwise, we use the given rate and reset the pilots
///////////////////////////////////////////////////////////////////////////////////////////////////
(* synthesize *)
module mkMapper(Mapper);
  Reg#(Bit#(127)) pilots <- mkReg('he275a0abd218d4cf928b9bbf6cb08f);
  Reg#(Bool) valid <- mkReg(False);
  Reg#(Bit#(288)) packet <- mkRegU;
  Reg#(DataRate) rate <- mkRegU;
  Reg#(Bool) rst <- mkRegU;

  Integer positions[48] = {
    -26,-25,-24,-23,-22,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-6,-5,-4,-3,-2,-1,
    1,2,3,4,5,6,8,9,10,11,12,13,14,15,16,17,18,19,20,22,23,24,25,26
  };

  for (Integer i=0; i < 24; i = i + 1) begin
    positions[i] = 64 + positions[i];
  end

  method Action put(Maybe#(DataRate) r, Bit#(288) p) if (!valid);
    rate <= isValid(r) ? validValue(r) : rate;
    rst <= isValid(r);
    valid <= True;
    packet <= p;
  endmethod

  method ActionValue#(Symbol) get if (valid);
    Symbol symbol = replicate(0);
    Bit#(1) pilot = pilots[0];

    if (rst) begin
      pilots <= 'he275a0abd218d4cf928b9bbf6cb08f;
      pilot = 1;
    end else begin
      pilots <= {pilot,pilots[126:1]};
    end

    symbol[7] = pilot == 1 ? 1 : -1;
    symbol[21] = pilot == 1 ? -1 : 1;
    symbol[64-7] = pilot == 1 ? 1 : -1;
    symbol[64-21] = pilot == 1 ? 1 : -1;

    Vector#(48,Bit#(1)) bpsk_indices = unpack(packet[47:0]);
    Vector#(48,Bit#(2)) qpsk_indices = unpack(packet[95:0]);
    Vector#(48,Bit#(4)) qam16_indices = unpack(packet[191:0]);
    Vector#(48,Bit#(6)) qam64_indices = unpack(packet[287:0]);

    for (Integer i=0; i < 48; i = i + 1) begin
      Cmplx carrier_coef = case (modulation_from_rate(rate)) matches
        BPSK : get_bpsk_value(bpsk_indices[i]);
        QPSK : get_qpsk_value(qpsk_indices[i]);
        QAM16 : get_qam16_value(qam16_indices[i]);
        QAM64 : get_qam64_value(qam64_indices[i]);
      endcase;

      symbol[positions[i]] = carrier_coef;
    end

    valid <= False;

    return symbol;
  endmethod
endmodule

interface DeMapper;
  method Action put(DataRate rate, Symbol symbol);
  method ActionValue#(Bit#(288)) get();
endinterface
