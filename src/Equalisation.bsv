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
  method Action put(Vector#(64,Cmplx) data);
  method ActionValue#(Vector#(64,Cmplx)) get;
  method Action rst;
endinterface

typedef enum {
  Idle,
  ConjMul,
  SendDivider,
  RecvDivider,
  MulNorm,
  WaitPacket
} Equalisation_State deriving(Bits, FShow, Eq);

(* synthesize *)
module mkEqualisation(Equalisation);
  Reg#(Vector#(64,Cmplx)) correction <- mkRegU;
  Reg#(Vector#(64,Cmplx)) packet <- mkRegU;
  Reg#(Fxpt) norm_acc <- mkReg(0);

  Reg#(Bit#(6)) index <- mkReg(0);

  Reg#(Equalisation_State) state <- mkReg(Idle);

  let multiplier <- mkMultiplier64;

  rule conj_mul if (state == ConjMul);
    if (index == 0) begin
      Vector#(64, Cmplx) lhs = newVector;
      Vector#(64, Cmplx) rhs = newVector;
      for (Integer i=0; i < 64; i = i + 1) lhs[i] = lts_frequencies[i];
      for (Integer i=0; i < 64; i = i + 1) rhs[i] = cmplxConj(correction[i]);
      multiplier.request.put(tuple2(lhs, rhs));
    end

    norm_acc <= norm_acc + (correction[index] * cmplxConj(correction[index])).rel;
    if (index + 1 == 0) state <= ConjMul;
    index <= index + 1;
  endrule

  rule send_divider if (state == SendDivider);
    let c <- multiplier.response.get;
    correction <= c;

    state <= RecvDivider;
  endrule

  rule recv_divider if (state == RecvDivider);
    let response = ?;

    multiplier.request.put(tuple2(correction, replicate(cmplx(response,0))));
    state <= MulNorm;
  endrule

  rule mul_norm if (state == MulNorm);
    let c <- multiplier.response.get;
    state <= WaitPacket;
    correction <= c;
  endrule
endmodule


(* synthesize *)
module mkMultiplier64(Server#(Tuple2#(Vector#(64,Cmplx),Vector#(64,Cmplx)), Vector#(64,Cmplx)));
  Reg#(Vector#(64,Cmplx)) lhs <- mkRegU;
  Reg#(Vector#(64,Cmplx)) rhs <- mkRegU;
  Reg#(Vector#(64,Cmplx)) ret <- mkRegU;

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
    endmethod
  endinterface

  interface Get response;
    method ActionValue#(Vector#(64,Cmplx)) get if (state == 2);
      state <= 0;
      return ret;
    endmethod
  endinterface
endmodule
