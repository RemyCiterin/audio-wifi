import BuildVector::*;
import FixedPoint::*;
import Complex::*;
import Vector::*;
import Real::*;

import SpecialFIFOs::*;
import RegFile::*;
import FIFOF::*;

import GetPut::*;
import ClientServer::*;

import Constants::*;

function Fmt formatFxpt(Fxpt x) provisos(Bits#(Fxpt,a));
  //return $format(fshow(Int#(a)'(unpack(pack(x)))));

  return $format("%d.%d", fshow(fxptGetInt(x)), fshow((fxptGetFrac(x)*100) >> 16));
endfunction

// 64-th unit roots: e^(2j * PI * k / 64) for k in [0, 63]
Cmplx unit_circle_64[64] = {
  cmplx(1.0, 0.0),cmplx(0.9951847266721969, 0.0980171403295606),
  cmplx(0.9807852804032304, 0.19509032201612825),cmplx(0.9569403357322088, 0.29028467725446233),
  cmplx(0.9238795325112867, 0.3826834323650898),cmplx(0.881921264348355, 0.47139673682599764),
  cmplx(0.8314696123025452, 0.5555702330196022),cmplx(0.773010453362737, 0.6343932841636455),
  cmplx(0.7071067811865476, 0.7071067811865475),cmplx(0.6343932841636455, 0.773010453362737),
  cmplx(0.5555702330196023, 0.8314696123025452),cmplx(0.4713967368259978, 0.8819212643483549),
  cmplx(0.38268343236508984, 0.9238795325112867),cmplx(0.29028467725446233, 0.9569403357322089),
  cmplx(0.19509032201612833, 0.9807852804032304),cmplx(0.09801714032956077, 0.9951847266721968),
  cmplx(0.0, 1.0),cmplx(-0.09801714032956065, 0.9951847266721969),
  cmplx(-0.1950903220161282, 0.9807852804032304),cmplx(-0.29028467725446216, 0.9569403357322089),
  cmplx(-0.3826834323650897, 0.9238795325112867),cmplx(-0.4713967368259977, 0.881921264348355),
  cmplx(-0.555570233019602, 0.8314696123025455),cmplx(-0.6343932841636454, 0.7730104533627371),
  cmplx(-0.7071067811865475, 0.7071067811865476),cmplx(-0.773010453362737, 0.6343932841636455),
  cmplx(-0.8314696123025453, 0.5555702330196022),cmplx(-0.8819212643483549, 0.47139673682599786),
  cmplx(-0.9238795325112867, 0.3826834323650899),cmplx(-0.9569403357322088, 0.2902846772544624),
  cmplx(-0.9807852804032304, 0.1950903220161286),cmplx(-0.9951847266721968, 0.09801714032956083),
  cmplx(-1.0, 0.0),cmplx(-0.9951847266721969, -0.09801714032956059),
  cmplx(-0.9807852804032304, -0.19509032201612836),cmplx(-0.9569403357322089, -0.2902846772544621),
  cmplx(-0.9238795325112868, -0.38268343236508967),cmplx(-0.881921264348355, -0.47139673682599764),
  cmplx(-0.8314696123025455, -0.555570233019602),cmplx(-0.7730104533627371, -0.6343932841636453),
  cmplx(-0.7071067811865477, -0.7071067811865475),cmplx(-0.6343932841636459, -0.7730104533627367),
  cmplx(-0.5555702330196022, -0.8314696123025452),cmplx(-0.47139673682599786, -0.8819212643483549),
  cmplx(-0.38268343236509034, -0.9238795325112865),cmplx(-0.29028467725446244, -0.9569403357322088),
  cmplx(-0.19509032201612866, -0.9807852804032303),cmplx(-0.09801714032956045, -0.9951847266721969),
  cmplx(0.0, -1.0),cmplx(0.09801714032956009, -0.9951847266721969),
  cmplx(0.1950903220161283, -0.9807852804032304),cmplx(0.29028467725446205, -0.9569403357322089),
  cmplx(0.38268343236509, -0.9238795325112866),cmplx(0.4713967368259976, -0.881921264348355),
  cmplx(0.5555702330196018, -0.8314696123025455),cmplx(0.6343932841636456, -0.7730104533627369),
  cmplx(0.7071067811865474, -0.7071067811865477),cmplx(0.7730104533627367, -0.6343932841636459),
  cmplx(0.8314696123025452, -0.5555702330196022),cmplx(0.8819212643483548, -0.4713967368259979),
  cmplx(0.9238795325112865, -0.3826834323650904),cmplx(0.9569403357322088, -0.2902846772544625),
  cmplx(0.9807852804032303, -0.19509032201612872),cmplx(0.9951847266721969, -0.0980171403295605)
};

function Cmplx complexTimesI(Cmplx x);
  return Complex{rel: - x.img, img: x.rel};
endfunction

// return the e^(2*i*pi*k/n) with k and n integers
function Cmplx complexExp(Integer k, Integer n);
  Real rPart = cos(2.0 * pi * fromInteger(k) / fromInteger(n));
  Real iPart = sin(2.0 * pi * fromInteger(k) / fromInteger(n));

  return cmplx(
    fromReal(rPart),
    fromReal(iPart)
  );
endfunction

// return the `x * e^(2*i*pi*k/n)` with `k` and `n` integers, also perform some optimisations
// for specific values of `k/n` (0, 1/2, 1/4, 3/4, 1/8, 3/8, 5/8, 7/8)
function Cmplx timesComplexExp(Cmplx x, Integer k, Integer n);
  if (k < 0) k = (k % n) + n;
  else k = k % n;

  if (k == 0) return x;
  else if (n == 2 * k) return -x;
  else if (n == 4 * k) return complexTimesI(x);
  else if (3 * n == 4 * k) return -complexTimesI(x);
  else if (n == 8 * k) return x * cmplx(fromReal(sqrt(2)/2), fromReal(sqrt(2)/2));
  else if (3 * n == 8 * k) return complexTimesI(timesComplexExp(x, 1, 8));
  else if (5 * n == 8 * k) return -timesComplexExp(x, 1, 8);
  else if (7 * n == 8 * k) return -complexTimesI(timesComplexExp(x, 1, 8));
  else begin
    Real rPart = cos(2.0 * pi * fromInteger(k) / fromInteger(n));
    Real iPart = sin(2.0 * pi * fromInteger(k) / fromInteger(n));

    return x * cmplx(
      fromReal(rPart),
      fromReal(iPart)
    );
  end
endfunction

interface FFT_IFC#(numeric type n);
  (* always_ready *) method Bool canEnq();
  method Action enq( Vector#(n, Cmplx) in );

  (* always_ready *) method Bool valid;
  (* always_ready *) method Vector#(n, Cmplx) response;
  method Action deq;
endinterface

module mkDFT#(Bool inverse) (FFT_IFC#(n));
  Reg#(Bool) idle[2] <- mkCReg(2, True);
  Reg#(Vector#(n, Cmplx)) state <- mkRegU;

  method canEnq = idle[1];
  method Action enq(Vector#(n, Cmplx) data) if (idle[1]);
    idle[1] <= False;
    state <= data;
  endmethod

  method valid = !idle[0];
  method Vector#(n, Cmplx) response;
    Vector#(n, Cmplx) out = replicate(0);

    for (Integer i=0; i < valueof(n); i = i + 1) begin
      for (Integer j=0; j < valueof(n); j = j + 1) begin
        if (inverse) out[i] = out[i] + timesComplexExp(state[j], i*j, valueof(n));
        else out[i] = out[i] + timesComplexExp(state[j], -i*j, valueof(n));
      end
    end

    return out;
  endmethod

  method Action deq if (!idle[0]);
    idle[0] <= True;
  endmethod
endmodule

(* synthesize *)
module mkFFT8#(Bool inverse) (FFT_IFC#(8));
  let fft <- mkDFT(inverse);
  return fft;
endmodule

(* synthesize *)
module mkFFT4#(Bool inverse) (FFT_IFC#(4));
  Reg#(Bool) idle[2] <- mkCReg(2, True);
  Reg#(Vector#(4, Cmplx)) state <- mkRegU;

  method canEnq = idle[1];
  method Action enq(Vector#(4, Cmplx) data) if (idle[1]);
    idle[1] <= False;
    state <= data;
  endmethod

  method valid = !idle[0];
  method Vector#(4, Cmplx) response;
    Vector#(4, Cmplx) out = newVector;

    Cmplx j = inverse ? cmplx(0,-1) : cmplx(0, 1);
    out[0] = state[0] + state[1] + state[2] + state[3];
    if (inverse) out[1] = state[0] + complexTimesI(state[1]) - state[2] - complexTimesI(state[3]);
    else out[1] = state[0] - complexTimesI(state[1]) - state[2] + complexTimesI(state[3]);
    out[2] = state[0] - state[1] + state[2] - state[3];
    if (inverse) out[3] = state[0] - complexTimesI(state[1]) - state[2] + complexTimesI(state[3]);
    else out[3] = state[0] + complexTimesI(state[1]) - state[2] - complexTimesI(state[3]);

    return out;
  endmethod

  method Action deq if (!idle[0]);
    idle[0] <= True;
  endmethod
endmodule

module mkCyclicFFTRadix4#(
  FFT_IFC#(n) fft
) (FFT_IFC#(TMul#(4, n)));
  Reg#(Vector#(4, Vector#(n, Cmplx))) output_buffer <- mkRegU;
  Reg#(Bit#(3)) output_state[2] <- mkCReg(2, 0);

  Reg#(Vector#(4, Vector#(n, Cmplx))) input_buffer <- mkRegU;
  Reg#(Bit#(3)) input_state[2] <- mkCReg(2, 0);

  rule send_input if (input_state[0] != 0 && fft.canEnq);
    fft.enq(input_buffer[input_state[0] - 1]);
    input_state[0] <= input_state[0] - 1;
  endrule

  Vector#(4, Vector#(n, Cmplx)) factors = replicate(replicate(0));

  for (Integer i=0; i < valueof(n); i = i + 1) begin
    factors[0][i] = 1;
    factors[1][i] = complexExp(- 1 * i, 4 * valueof(n));
    factors[2][i] = complexExp(- 2 * i, 4 * valueof(n));
    factors[3][i] = complexExp(- 3 * i, 4 * valueof(n));
  end

  FIFOF#(Vector#(n, Cmplx)) fft_output <- mkPipelineFIFOF;

  rule from_fft;
    fft_output.enq(fft.response);
    fft.deq;
  endrule

  rule receive_output if (output_state[1] != 4);
    Vector#(n, Cmplx) out = fft_output.first;

    for (Integer i=0; i < valueof(n); i = i + 1) begin
      out[i] = factors[output_state[1]][i] * out[i];
    end

    output_state[1] <= output_state[1] + 1;
    output_buffer[output_state[1]] <= out;
    fft_output.deq;
  endrule

  method canEnq = input_state[1] == 0;
  method Action enq(Vector#(TMul#(4,n), Cmplx) data) if (input_state[1] == 0);
    input_state[1] <= 4;

    Vector#(4, Vector#(n, Cmplx)) in = replicate(replicate(0));
    for (Integer i=0; i < valueof(n); i = i + 1) begin
      in[3][i] = data[4 * i + 0];
      in[2][i] = data[4 * i + 1];
      in[1][i] = data[4 * i + 2];
      in[0][i] = data[4 * i + 3];
    end

    input_buffer <= in;
  endmethod

  method valid = output_state[0] == 4;

  method Vector#(TMul#(4,n), Cmplx) response;
    Vector#(TMul#(4,n), Cmplx) out = replicate(0);

    for (Integer i=0; i < valueof(n); i = i + 1) begin
      Cmplx x0 = output_buffer[0][i];
      Cmplx x1 = output_buffer[1][i];
      Cmplx x2 = output_buffer[2][i];
      Cmplx x3 = output_buffer[3][i];

      out[0 * valueof(n) + i] = x0 + x1 + x2 + x3;
      out[1 * valueof(n) + i] = x0 - complexTimesI(x1) - x2 + complexTimesI(x3);
      out[2 * valueof(n) + i] = x0 - x1 + x2 - x3;
      out[3 * valueof(n) + i] = x0 + complexTimesI(x1) - x2 - complexTimesI(x3);
    end

    return out;
  endmethod

  method Action deq if (output_state[0] == 4);
    output_state[0] <= 0;
  endmethod
endmodule

module mkRowColFFT#(
  Bool inverse,
  FFT_IFC#(n) fft_n,
  FFT_IFC#(m) fft_m
)(FFT_IFC#(TMul#(n, m)));
  Reg#(Bit#(TLog#(n))) input_row <- mkReg(0);
  Reg#(Bit#(n)) input_valid[2] <- mkCReg(2, 0);
  Reg#(Vector#(n, Vector#(m, Cmplx))) input_buf <- mkRegU;

  Reg#(Vector#(n, Vector#(m, Bool))) tmp_valid[2] <- mkCReg(2, replicate(replicate(False)));
  Reg#(Vector#(n, Vector#(m, Cmplx))) tmp_buf <- mkRegU;
  Reg#(Bit#(TLog#(n))) tmp_row <- mkReg(0);
  Reg#(Bit#(TLog#(m))) tmp_col <- mkReg(0);

  Reg#(Bit#(TLog#(m))) output_row <- mkReg(0);
  Reg#(Bit#(m)) output_valid[2] <- mkCReg(2, 0);
  Reg#(Vector#(m, Vector#(n, Cmplx))) output_buf <- mkRegU;

  rule input_to_fft if (input_valid[0][input_row] == 1);
    input_row <= input_row == fromInteger(valueof(n) - 1) ? 0 : input_row + 1;
    fft_m.enq(input_buf[input_row]);
    input_valid[0][input_row] <= 0;
  endrule

  rule fft_to_tmp if (tmp_valid[1][tmp_row] == replicate(False));
    tmp_row <= tmp_row == fromInteger(valueof(n) - 1) ? 0 : tmp_row + 1;
    tmp_valid[1][tmp_row] <= replicate(True);
    tmp_buf[tmp_row] <= fft_m.response;
    fft_m.deq;
  endrule

  Vector#(n, Vector#(m, Cmplx)) twiddles = replicate(replicate(0));

  for (Integer i=0; i < valueof(n); i = i + 1) begin
    for (Integer j=0; j < valueof(m); j = j + 1) begin
      if (inverse) twiddles[i][j] = complexExp(i*j, valueof(n) * valueof(m));
      else twiddles[i][j] = complexExp(-i*j, valueof(n) * valueof(m));
    end
  end

  rule tmp_to_fft if (transpose(tmp_valid[0])[tmp_col] == replicate(True));
    tmp_col <= tmp_col == fromInteger(valueof(m) - 1) ? 0 : tmp_col + 1;

    Vector#(n, Cmplx) col = replicate(0);
    Vector#(n, Vector#(m, Bool)) valid = tmp_valid[0];
    for (Integer i=0; i < valueof(n); i = i + 1) begin
      col[i] = tmp_buf[i][tmp_col] * twiddles[i][tmp_col];
      valid[i][tmp_col] = False;
    end

    tmp_valid[0] <= valid;
    fft_n.enq(col);
  endrule

  rule fft_to_output if (output_valid[1][output_row] == 0);
    output_row <= output_row == fromInteger(valueof(m) - 1) ? 0 : output_row + 1;
    output_buf[output_row] <= fft_n.response;
    output_valid[1][output_row] <= 1;
    fft_n.deq;
  endrule

  method canEnq = input_valid[1] == 0;

  method Action enq(Vector#(TMul#(n,m), Cmplx) in) if (input_valid[1] == 0);
    input_buf <= transpose(unpack(pack(in)));
    input_valid[1] <= '1;
  endmethod

  method valid = output_valid[0] == '1;
  method response;
    return unpack(pack(transpose(output_buf)));
  endmethod

  method Action deq if (output_valid[0] == '1);
    output_valid[0] <= 0;
  endmethod
endmodule

module mkPipelineFFTRadix4#(
  FFT_IFC#(n) fft0,
  FFT_IFC#(n) fft1,
  FFT_IFC#(n) fft2,
  FFT_IFC#(n) fft3
) (FFT_IFC#(TMul#(4, n)));

  method canEnq = fft0.canEnq && fft1.canEnq && fft2.canEnq && fft3.canEnq;

  method Action enq(Vector#(TMul#(4, n), Cmplx) in);
    Vector#(n, Cmplx) in0 = replicate(0);
    Vector#(n, Cmplx) in1 = replicate(0);
    Vector#(n, Cmplx) in2 = replicate(0);
    Vector#(n, Cmplx) in3 = replicate(0);

    for (Integer i=0; i < valueof(n); i = i + 1) begin
      in0[i] = in[4 * i + 0];
      in1[i] = in[4 * i + 1];
      in2[i] = in[4 * i + 2];
      in3[i] = in[4 * i + 3];
    end

    fft0.enq(in0);
    fft1.enq(in1);
    fft2.enq(in2);
    fft3.enq(in3);
  endmethod

  method Bool valid = fft0.valid && fft1.valid && fft2.valid && fft3.valid;

  method Vector#(TMul#(4, n), Cmplx) response;
    Vector#(TMul#(4, n), Cmplx) out = replicate(0);

    for (Integer i=0; i < valueof(n); i = i + 1) begin
      Cmplx x0 = fft0.response[i];
      Cmplx x1 = fft1.response[i] * complexExp(- 1 * i, 4 * valueof(n));
      Cmplx x2 = fft2.response[i] * complexExp(- 2 * i, 4 * valueof(n));
      Cmplx x3 = fft3.response[i] * complexExp(- 3 * i, 4 * valueof(n));

      out[0 * valueof(n) + i] = x0 + x1 + x2 + x3;
      out[1 * valueof(n) + i] = x0 - complexTimesI(x1) - x2 + complexTimesI(x3);
      out[2 * valueof(n) + i] = x0 - x1 + x2 - x3;
      out[3 * valueof(n) + i] = x0 + complexTimesI(x1) - x2 - complexTimesI(x3);
    end

    return out;
  endmethod

  method Action deq;
    fft0.deq;
    fft1.deq;
    fft2.deq;
    fft3.deq;
  endmethod
endmodule

module mkStreamFFT#(Bool inverse) (FFT_IFC#(n));
  Integer n = valueof(n);

  Server#(Cmplx, Cmplx) stages[log2(n)];
  for (Integer stage=0; stage < log2(n); stage = stage + 1) begin
    stages[stage] <- mkStageStreamFFT(inverse, 2 ** stage);
  end

  Reg#(Bool) input_valid[2] <- mkCReg(2, False);
  Reg#(Bit#(TLog#(n))) input_index <- mkReg(0);
  Reg#(Vector#(n, Cmplx)) input_buffer <- mkRegU;

  Reg#(Bit#(TLog#(TAdd#(n, 1)))) output_index[2] <- mkCReg(2, fromInteger(0));
  Reg#(Vector#(n, Cmplx)) output_buffer <- mkRegU;

  rule send_input if (input_valid[0]);
    stages[0].request.put(input_buffer[reverseBits(input_index)]);
    if (input_index + 1 == 0) input_valid[0] <= False;
    input_index <= input_index + 1;
  endrule

  for (Integer i=1; i < log2(n); i = i + 1) begin
    rule propagate;
      let x <- stages[i-1].response.get;
      stages[i].request.put(x);
    endrule
  end

  rule receive_output if (output_index[1] < fromInteger(n));
    let x <- stages[log2(n)-1].response.get;
    output_index[1] <= output_index[1] + 1;
    output_buffer[output_index[1]] <= x;
  endrule

  method canEnq = !input_valid[1];
  method Action enq (Vector#(n, Cmplx) data) if (!input_valid[1]);
    input_valid[1] <= True;
    input_buffer <= data;
  endmethod

  method response = output_buffer;
  method valid = output_index[0] == fromInteger(n);
  method Action deq if (output_index[0] == fromInteger(n));
    output_index[0] <= 0;
  endmethod
endmodule

interface ShiftReg#(type t);
  (* always_ready *) method t first;
  (* always_ready *) method Action push(t value);
endinterface

module mkShiftReg#(Integer n, function t init(Integer i)) (ShiftReg#(t)) provisos(Bits#(t, tW));
  Reg#(t) buffer[n];
  for (Integer i=0; i < n; i = i + 1) begin
    buffer[i] <- mkReg(init(i));
  end

  method t first = buffer[0];

  method Action push(t value);
    buffer[n - 1] <= value;
    for (Integer i=0; i < n - 1; i = i + 1) begin
      buffer[i] <= buffer[i + 1];
    end
  endmethod
endmodule

module mkStageStreamFFT#(Bool inverse, Integer n) (Server#(Cmplx, Cmplx));
  FIFOF#(Cmplx) requests <- mkPipelineFIFOF;
  FIFOF#(Cmplx) responses <- mkBypassFIFOF;

  if (n > 2**16) errorM("Stream FFT doesn't support more than 64K samples");
  Reg#(Bit#(16)) flush_counter <- mkReg(fromInteger(n));
  Reg#(Bit#(16)) counter <- mkReg(0);
  Reg#(Bit#(1)) stage <- mkReg(0);

  function Cmplx computeTwiddle(Integer i);
    if (inverse) return complexExp(i, 2*n);
    else return complexExp(-i, 2*n);
  endfunction
  ShiftReg#(Cmplx) twiddles <- mkShiftReg(n, computeTwiddle);

  ShiftReg#(Cmplx) tmp_buffer <- mkShiftReg(n, constFn(?));
  ShiftReg#(Cmplx) out_buffer <- mkShiftReg(n, constFn(?));

  function Action update_counter;
    action
      Bool finish = counter == fromInteger(n-1);
      stage <= finish ? stage + 1 : stage;
      counter <= finish ? 0 : counter + 1;
      twiddles.push(twiddles.first);
    endaction
  endfunction

  rule stage0 if (stage == 0);
    // make sure that we flush the buffer faster that we write it
    if (flush_counter < fromInteger(n)) begin
      flush_counter <= flush_counter + 1;
      responses.enq(out_buffer.first);
      out_buffer.push(?);
    end

    if (requests.notEmpty) begin
      tmp_buffer.push(requests.first);
      update_counter;
      requests.deq;
    end
  endrule

  // Apply the butterfly to the values in the shift register and the request,
  // return the first output, and save the second into the shift register
  rule stage1 if (stage == 1);
    Cmplx x = tmp_buffer.first;
    // Compute `requests.first * twiddles.first` with three multipliers
    Fxpt m1 = requests.first.rel * twiddles.first.rel;
    Fxpt m2 = requests.first.img * twiddles.first.img;
    Fxpt m3 = (requests.first.rel+requests.first.img) * (twiddles.first.rel+twiddles.first.img);
    Cmplx y = cmplx(m1-m2, m3-m1-m2);

    tmp_buffer.push(?);
    out_buffer.push(x - y);
    responses.enq(x + y);
    update_counter;
    requests.deq;

    // To make sure that flush_counter start at 0 at the stage 0
    flush_counter <= 0;
  endrule

  interface request = toPut(requests);
  interface response = toGet(responses);
endmodule

(* synthesize *)
module mkPipelineFFT16(FFT_IFC#(16));
  FFT_IFC#(4) fft0 <- mkFFT4(False);
  FFT_IFC#(4) fft1 <- mkFFT4(False);
  FFT_IFC#(4) fft2 <- mkFFT4(False);
  FFT_IFC#(4) fft3 <- mkFFT4(False);

  let fft <- mkPipelineFFTRadix4(fft0, fft1, fft2, fft3);
  return fft;
endmodule

(* synthesize *)
module mkCyclicFFT16(FFT_IFC#(16));
  FFT_IFC#(4) fft0 <- mkFFT4(False);

  let fft <- mkCyclicFFTRadix4(fft0);
  return fft;
endmodule

(* synthesize *)
module mkRowColFFT64#(Bool inverse) (FFT_IFC#(64));
  FFT_IFC#(8) fft0 <- mkFFT8(inverse);
  FFT_IFC#(8) fft1 <- mkFFT8(inverse);
  let fft <- mkRowColFFT(inverse, fft0, fft1);
  return fft;
endmodule

(* synthesize *)
module mkRowColFFT32#(Bool inverse) (FFT_IFC#(32));
  FFT_IFC#(4) fft4 <- mkFFT4(inverse);
  FFT_IFC#(8) fft8 <- mkFFT8(inverse);
  let fft <- mkRowColFFT(inverse, fft8, fft4);
  return fft;
endmodule

(* synthesize *)
module mkRowColFFT16#(Bool inverse) (FFT_IFC#(16));
  FFT_IFC#(4) fft0 <- mkFFT4(inverse);
  FFT_IFC#(4) fft1 <- mkFFT4(inverse);
  let fft <- mkRowColFFT(inverse, fft0, fft1);
  return fft;
endmodule

(* synthesize *)
module mkStreamFFT64(FFT_IFC#(64));
  let fft <- mkStreamFFT(False);
  return fft;
endmodule

(* synthesize *)
module mkStreamIFFT64(FFT_IFC#(64));
  let fft <- mkStreamFFT(True);
  return fft;
endmodule
