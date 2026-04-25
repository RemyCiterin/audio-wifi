import FixedPoint::*;
import Complex::*;
import Real::*;

import Constants::*;
import CORDIC::*;
import FFT::*;

import ClientServer::*;
import GetPut::*;

import SpecialFIFOs::*;
import FIFOF::*;

import Divide::*;
import Vector::*;

export Equalisation(..);
export mkEqualisation;

// Frequency domain representation of the long training sequence
Cmplx lts_frequencies[64] = {
   0,1,-1,-1,1,1,-1,1,-1,1,-1,-1,-1,-1,-1,1,
   1,-1,-1,1,-1,1,-1,1,1,1,1,0,0,0,0,0,
   0,0,0,0,0,0,1,1,-1,-1,1,1,-1,1,-1,1,
   1,1,1,1,1,-1,-1,1,1,-1,1,-1,1,1,1,1
};

interface Equalisation;
  method Action put(Symbol data);
  method ActionValue#(Symbol) get;
  method Action rst;
endinterface

typedef enum {
  Idle,
  SendConjMul,
  RecvConjMul,
  SendDivider,
  RecvDivider,
  WaitPacket,
  ProcessPacket
} Equalisation_State deriving(Bits, FShow, Eq);

(* synthesize *)
module mkEqualisation(Equalisation);
  Reg#(Symbol) correction <- mkRegU;
  Reg#(Symbol) lts <- mkRegU;

  Reg#(Bit#(6)) index <- mkReg(0);

  Reg#(Equalisation_State) state <- mkReg(Idle);

  let multiplier <- mkMultiplier64;

  let inverter <- mkFxptInverter;

  rule send_conj_mul if (state == SendConjMul);
    Vector#(64, Cmplx) lhs = newVector;
    Vector#(64, Cmplx) rhs = newVector;
    for (Integer i=0; i < 64; i = i + 1) lhs[i] = lts_frequencies[i];
    for (Integer i=0; i < 64; i = i + 1) rhs[i] = cmplxConj(lts[i]);
    multiplier.request.put(tuple2(lhs, rhs));
    state <= RecvConjMul;
  endrule

  rule recv_conj_mul if (state == RecvConjMul);
    let c <- multiplier.response.get;
    state <= SendDivider;
    correction <= c;
  endrule

  rule send_divider if (state == SendDivider);
    inverter.request.put((lts[index] * cmplxConj(lts[index])).rel);
    state <= RecvDivider;
  endrule

  rule recv_divider if (state == RecvDivider);
    let response <- inverter.response.get;
    correction[index] <= correction[index] * cmplx(response, 0);
    state <= index + 1 == 0 ? WaitPacket : SendDivider;
    index <= index + 1;
  endrule

  method Action put(Symbol data) if (state == Idle || state == WaitPacket);
    if (state == Idle) begin
      state <= SendConjMul;
      lts <= data;
    end else begin
      multiplier.request.put(tuple2(data, correction));
      state <= ProcessPacket;
    end
  endmethod

  method Action rst if (state == WaitPacket);
    state <= Idle;
  endmethod

  method ActionValue#(Symbol) get if (state == ProcessPacket);
    let response <- multiplier.response.get;
    state <= WaitPacket;
    return response;
  endmethod
endmodule

///////////////////////////////////////////////////////////////////////////////////////////////////
// Perform the multiplication of two 64 complex points vectors with 66 cycles of latency
///////////////////////////////////////////////////////////////////////////////////////////////////
(* synthesize *)
module mkMultiplier64(Server#(Tuple2#(Symbol,Symbol), Symbol));
  Reg#(Symbol) lhs <- mkRegU;
  Reg#(Symbol) rhs <- mkRegU;
  Reg#(Symbol) ret <- mkRegU;

  Reg#(Bit#(2)) state <- mkReg(0);
  Reg#(Bit#(6)) index <- mkReg(0);

  rule process if (state == 1);
    ret[index] <= lhs[index] * rhs[index];
    if (index + 1 == 0) state <= 2;
    index <= index + 1;
  endrule

  interface Put request;
    method Action put(data) if (state == 0);
      lhs <= data.fst;
      rhs <= data.snd;
      state <= 1;
    endmethod
  endinterface

  interface Get response;
    method ActionValue#(Symbol) get if (state == 2);
      state <= 0;
      return ret;
    endmethod
  endinterface
endmodule

///////////////////////////////////////////////////////////////////////////////////////////////////
// Compute the inverse of a fixed point (1/x)
///////////////////////////////////////////////////////////////////////////////////////////////////
(* synthesize *)
module mkFxptInverter(Server#(Fxpt,Fxpt))
  provisos(Alias#(FixedPoint#(i,f), Fxpt), Add#(i,f,n));
  Server#(Tuple2#(Int#(TAdd#(n,n)),Int#(n)),Tuple2#(Int#(n),Int#(n)))
    divider <- mkNonPipelinedSignedDivider(1);

  interface Put request;
    method Action put(Fxpt x);
      divider.request.put(tuple2(1 << (2*valueof(f)), unpack(pack(x))));
    endmethod
  endinterface

  interface Get response;
    method ActionValue#(Fxpt) get;
      let ret <- divider.response.get;
      return unpack(pack(ret.fst));
    endmethod
  endinterface
endmodule
