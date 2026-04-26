import FixedPoint::*;
import Real::*;

import FIFOF::*;
import SpecialFIFOs::*;
import ClientServer::*;
import StmtFSM::*;
import GetPut::*;

////////////////////////////////////////////////////////////////////////////////////////////
// A CORDIC algorithm used to find the cosinus and sinus of an angle in fixed point,
// given an input `a`, it returns `tuple2(cos(a), sin(a))`.
//
// The depth agruement correspond to the latency of the module (in cycles), and it control
// the precision of the algorithm: it's the number of iterations of CORDIC.
////////////////////////////////////////////////////////////////////////////////////////////
module mkCosSinCordic#(
  Integer depth
)(Server#(FixedPoint#(i,f), Tuple2#(FixedPoint#(i,f),FixedPoint#(i,f))))
provisos(Add#(i,f,n), Alias#(fix, FixedPoint#(i,f)), Min#(i,1,1), Min#(n,2,2));

  Reg#(fix) alpha[depth];
  Reg#(fix) theta[depth];
  Reg#(fix) x_coord[depth];
  Reg#(fix) y_coord[depth];
  Reg#(Bool) valid[depth][2];

  for (Integer i=0; i < depth; i = i + 1) begin
    valid[i] <- mkCReg(2, False);
    x_coord[i] <- mkRegU;
    y_coord[i] <- mkRegU;
    theta[i] <- mkRegU;
    alpha[i] <- mkRegU;
  end

  for (Integer i=0; i < depth-1; i = i + 1) begin
    rule step if (valid[i][0] && !valid[i+1][1]);
      fix sigma = theta[i] < alpha[i] ? 1 : -1;
      theta[i+1] <= theta[i] + sigma * fromReal(atan2(1, fromInteger(2**i)));
      x_coord[i+1] <= x_coord[i] - ((sigma * y_coord[i]) >> i);
      y_coord[i+1] <= y_coord[i] + ((sigma * x_coord[i]) >> i);
      alpha[i+1] <= alpha[i];
      valid[i+1][1] <= True;
      valid[i][0] <= False;
    endrule
  end

  interface Put request;
    method Action put(fix a) if (!valid[0][1]);
      Bool inBounds = -fromReal(pi/2) <= a && a <= fromReal(pi/2);
      theta[0] <= inBounds ? 0 : (a > 0 ? fromReal(pi) : -fromReal(pi));
      x_coord[0] <= inBounds ? 1 : -1;
      valid[0][1] <= True;
      y_coord[0] <= 0;
      alpha[0] <= a;
    endmethod
  endinterface

  interface Get response;
    method ActionValue#(Tuple2#(fix, fix)) get if (valid[depth-1][0]);
      Real k = 1.0;
      for (Integer i=0; i < depth; i = i + 1) begin
        k = k / sqrt(1 + 2 ** (-2*fromInteger(i)));
      end

      valid[depth-1][0] <= False;
      return tuple2(x_coord[depth-1] * fromReal(k), y_coord[depth-1] * fromReal(k));
    endmethod
  endinterface
endmodule

////////////////////////////////////////////////////////////////////////////////////////////
// A CORDIC algorithm used to find the angle of a vector in the complex plane, given an
// input `tuple2(y, x)`, it returns `atan2(y, x)`
//
// The depth agruement correspond to the latency of the module (in cycles), and it control
// the precision of the algorithm: it's the number of iterations of CORDIC.
////////////////////////////////////////////////////////////////////////////////////////////
module mkAtanCordic#(
  Integer depth
) (Server#(Tuple2#(FixedPoint#(i,f),FixedPoint#(i,f)), FixedPoint#(i,f)))
provisos(Add#(i,f,n), Alias#(fix, FixedPoint#(i,f)), Min#(i,1,1), Min#(n,2,2));
  Reg#(fix) theta[depth];
  Reg#(fix) x_coord[depth];
  Reg#(fix) y_coord[depth];
  Reg#(Bool) valid[depth][2];

  for (Integer i=0; i < depth; i = i + 1) begin
    valid[i] <- mkCReg(2, False);
    x_coord[i] <- mkRegU;
    y_coord[i] <- mkRegU;
    theta[i] <- mkRegU;
  end

  for (Integer i=0; i < depth-1; i = i + 1) begin
    rule step if (valid[i][0] && !valid[i+1][1]);
      fix sigma = y_coord[i] > 0 ? -1 : 1;

      // Overflow logic
      fix x = x_coord[i];
      fix y = y_coord[i];
      Integer msb = valueof(n)-1;
      if (pack(x)[msb] != pack(x)[msb-1] || pack(y)[msb] != pack(y)[msb-1]) begin
        x = x >> 1;
        y = y >> 1;
      end

      theta[i+1] <= theta[i] - sigma * fromReal(atan2(1, fromInteger(2**i)));
      x_coord[i+1] <= x - ((sigma * y) >> i);
      y_coord[i+1] <= y + ((sigma * x) >> i);

      valid[i+1][1] <= True;
      valid[i][0] <= False;
    endrule
  end

  interface Put request;
    method Action put(Tuple2#(fix, fix) pair) if (!valid[0][1]);
      valid[0][1] <= True;
      match {.y, .x} = pair;
      theta[0] <= x > 0 ? 0 : y > 0 ? fromReal(pi) : -fromReal(pi);
      x_coord[0] <= x > 0 ? x : -x;
      y_coord[0] <= x > 0 ? y : -y;
    endmethod
  endinterface

  interface Get response;
    method ActionValue#(fix) get if (valid[depth-1][0]);
      valid[depth-1][0] <= False;
      return theta[depth-1];
    endmethod
  endinterface
endmodule

(* synthesize *)
module mkCordicTest(Empty) provisos(Alias#(FixedPoint#(8,16), fix));
  Server#(Tuple2#(fix, fix), fix) cordic1 <- mkAtanCordic(16);
  Server#(fix, Tuple2#(fix, fix)) cordic2 <- mkCosSinCordic(16);

  Real test_angle = -pi;
  Real test_x = -0.5;
  Real test_y = 0.5;

  mkAutoFSM(seq
    cordic1.request.put(tuple2(fromReal(test_y), fromReal(test_x)));
    action
      let x <- cordic1.response.get();
      $display("======== ATAN 2 ========");
      $display("atan2;  ", realToString(atan2(test_y, test_x)));
      $display("approx: "); fxptWrite(6, x); $display;
    endaction

    cordic2.request.put(fromReal(test_angle));
    action
      let x <- cordic2.response.get();
      $display("======== Cos/Sin ========");
      $display("cosinus: ", realToString(cos(test_angle)));
      $display("sinus: ", realToString(sin(test_angle)));
      $write("approx:  "); fxptWrite(6,x.fst); $write(" "); fxptWrite(6, x.snd); $display;
    endaction
  endseq);
endmodule
