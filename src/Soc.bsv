import StmtFSM::*;
import FFT::*;

import ClientServer::*;
import FixedPoint::*;
import Complex::*;
import GetPut::*;
import Vector::*;
import Real::*;

import Scrambler::*;
import Constants::*;
import Header::*;
import CORDIC::*;

import Equalisation::*;
import Detection::*;

import Mapper::*;

interface SOC_IFC;
  (* always_ready, always_enabled *)
  method Bit#(8) led;

  (* always_ready, always_enabled, prefix="" *)
  method Action btn((* port="btn" *)Bool in);
endinterface

typedef 64 FFT_SIZE;

(* synthesize *)
module mkSoc(SOC_IFC);
  Reg#(Bool) start <- mkReg(False);

  FFT_IFC#(FFT_SIZE) fft <- mkStreamFFT64;

  Vector#(FFT_SIZE, Cmplx) vector = replicate(0);

  for (Integer i = 0; i < valueof(FFT_SIZE); i = i + 1) begin
    Real rPart = cos(2.0 * pi * fromInteger(i) / fromInteger(valueof(FFT_SIZE)));
    Real iPart = sin(2.0 * pi * fromInteger(i) / fromInteger(valueof(FFT_SIZE)));
    vector[i] = cmplx(fromReal(rPart), fromReal(iPart));
  end

  //let cordic_test <- mkCordicTest;

  let test <- mkTestSynchronizer;

  //mkAutoFSM(seq
  //  while (!start) noAction;

  //  //par
  //  //  while (True) fft.enq(vector);
  //  //  while (True) action
  //  //    fft.deq;
  //  //    Bit#(64) t <- $time;
  //  //    $display("%d", t / 10);
  //  //    if (t > 10000) $finish;
  //  //  endaction
  //  //endpar

  //  fft.enq(vector);

  //  action
  //    fft.deq;
  //    for (Integer i=0; i < valueof(FFT_SIZE); i = i + 1) begin
  //      $write(formatFxpt(fft.response[i].rel), ", ");
  //      $write(formatFxpt(fft.response[i].img));
  //      $display;
  //    end
  //  endaction
  //endseq);

  Fxpt x = 0;
  for (Integer i=0; i < valueof(FFT_SIZE); i = i + 1) begin
    x = x + fft.response[i].rel + fft.response[i].img;
  end

  method led = truncate(x.i);
  method btn = start._write;
endmodule

module mkSocSim(Empty);
  let soc <- mkSoc;
  rule start_rl;
    soc.btn(True);
  endrule
endmodule
