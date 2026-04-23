// This stage is in charge of detecting the begining of a WIFI frame using Schmidl & Cox algorithm.

import GetPut::*;
import Constants::*;
import ClientServer::*;
import FixedPoint::*;
import Complex::*;
import RegFile::*;
import Vector::*;

import CORDIC::*;
import FFT::*;

import SpecialFIFOs::*;
import BRAMCore::*;
import StmtFSM::*;
import RegFile::*;
import FIFOF::*;
import Real::*;

export Synchronizer(..);
export mkSynchronizer;
export mkTestSynchronizer;

`ifdef BSIM
import "BDPI" function Action clear_graph();
import "BDPI" function Action render_graph();
import "BDPI" function Action color_graph(Bit#(8) r, Bit#(8) g, Bit#(8) b);
import "BDPI" function Action draw_graph
  (Bit#(32) x, Bit#(32) y, Bit#(32) scale_x, Bit#(32) scale_y);
`else
function Action clear_graph() = noAction;
function Action render_graph() = noAction;
function Action color_graph(Bit#(8) r, Bit#(8) g, Bit#(8) b) = noAction;
function Action draw_graph
  (Bit#(32) x, Bit#(32) y, Bit#(32) scale_x, Bit#(32) scale_y) = noAction;
`endif

// Frequency domain representation of the long training sequence
C16 lts_frequencies[64] = {
   0,1,-1,-1,1,1,-1,1,-1,1,-1,-1,-1,-1,-1,1,
   1,-1,-1,1,-1,1,-1,1,1,1,1,0,0,0,0,0,
   0,0,0,0,0,0,1,1,-1,-1,1,1,-1,1,-1,1,
   1,1,1,1,1,-1,-1,1,1,-1,1,-1,1,1,1,1
};

C16 lts_times[64] = {
  cmplx(0.15625, 0.0), cmplx(-0.0051213, -0.12033),
  cmplx(0.03975, -0.11116), cmplx(0.096832, 0.082798),
  cmplx(0.021112, 0.027886), cmplx(0.059824, -0.087707),
  cmplx(-0.11513, -0.05518), cmplx(-0.038316, -0.10617),
  cmplx(0.097541, -0.025888), cmplx(0.053338, 0.0040763),
  cmplx(0.00098898, -0.115), cmplx(-0.1368, -0.04738),
  cmplx(0.024476, -0.058532), cmplx(0.058669, -0.014939),
  cmplx(-0.022483, 0.16066), cmplx(0.11924, -0.0040956),
  cmplx(0.0625, -0.0625), cmplx(0.036918, 0.098344),
  cmplx(-0.057206, 0.039299), cmplx(-0.13126, 0.065227),
  cmplx(0.082218, 0.092357), cmplx(0.069557, 0.014122),
  cmplx(-0.06031, 0.081286), cmplx(-0.056455, -0.021804),
  cmplx(-0.035041, -0.15089), cmplx(-0.12189, -0.016566),
  cmplx(-0.12732, -0.020501), cmplx(0.075074, -0.07404),
  cmplx(-0.0028059, 0.053774), cmplx(-0.091888, 0.11513),
  cmplx(0.091717, 0.10587), cmplx(0.012285, 0.0976),
  cmplx(-0.15625, 0.0), cmplx(0.012285, -0.0976),
  cmplx(0.091717, -0.10587), cmplx(-0.091888, -0.11513),
  cmplx(-0.0028059, -0.053774), cmplx(0.075074, 0.07404),
  cmplx(-0.12732, 0.020501), cmplx(-0.12189, 0.016566),
  cmplx(-0.035041, 0.15089), cmplx(-0.056455, 0.021804),
  cmplx(-0.06031, -0.081286), cmplx(0.069557, -0.014122),
  cmplx(0.082218, -0.092357), cmplx(-0.13126, -0.065227),
  cmplx(-0.057206, -0.039299), cmplx(0.036918, -0.098344),
  cmplx(0.0625, 0.0625), cmplx(0.11924, 0.0040956),
  cmplx(-0.022483, -0.16066), cmplx(0.058669, 0.014939),
  cmplx(0.024476, 0.058532), cmplx(-0.1368, 0.04738),
  cmplx(0.00098898, 0.115), cmplx(0.053338, -0.0040763),
  cmplx(0.097541, 0.025888), cmplx(-0.038316, 0.10617),
  cmplx(-0.11513, 0.05518), cmplx(0.059824, 0.087707),
  cmplx(0.021112, -0.027886), cmplx(0.096832, -0.082798),
  cmplx(0.03975, 0.11116), cmplx(-0.0051213, 0.12033)
};

interface LtsCorrelator;
  // Add a new sample to the correlator
  method Action push(C16 sample);

  // Give the result with a delay of 64 samples
  method Bit#(20) result;
endinterface

(* synthesize *)
module mkltsCorrelator(LtsCorrelator);
  Vector#(64, Reg#(Int#(10))) rel_buffer <- replicateM(mkReg(0));
  Vector#(64, Reg#(Int#(10))) img_buffer <- replicateM(mkReg(0));

  method Action push(C16 sample);
    Bit#(1) rel = msb(sample.rel);
    Bit#(1) img = msb(sample.img);

    for (Integer i=0; i < 64; i = i + 1) begin
      Int#(10) acc_rel = i == 0 ? 0 : rel_buffer[i-1];
      Int#(10) acc_img = i == 0 ? 0 : img_buffer[i-1];
      Bit#(1) lts_img = ~msb(lts_times[i].img);
      Bit#(1) lts_rel = msb(lts_times[i].rel);

      Int#(10) rr = (lts_rel ^ rel) == 1 ? -1 : 1;
      Int#(10) ii = (lts_img ^ img) == 1 ? -1 : 1;
      Int#(10) ri = (lts_rel ^ img) == 1 ? -1 : 1;
      Int#(10) ir = (lts_img ^ rel) == 1 ? -1 : 1;

      rel_buffer[i] <= rr - ii + acc_rel;
      img_buffer[i] <= ir + ri + acc_img;
    end
  endmethod

  method result =
    signExtend(pack(rel_buffer[63])) * signExtend(pack(rel_buffer[63])) +
    signExtend(pack(img_buffer[63])) * signExtend(pack(img_buffer[63]));
endmodule

interface Synchronizer;
  // Send a new sample to the synchronizer
  method Action put_sample(C16 sample);

  // An OFDM symbol extracted from the input samples by the synchronizer
  method ActionValue#(Vector#(64, C16)) get_ofdm_symbol;

  // Inform the synchronizer of the end of a frame
  method Action back_to_idle;
endinterface

typedef enum {
  Idle,
  WaitForLts,
  Lts
} Synchronizer_State deriving(Bits, Eq, FShow);

module mkSynchronizer(Synchronizer);
  LtsCorrelator correlator <- mkltsCorrelator;

  // use a sized fifo because some computations (like cordic can take time)
  FIFOF#(C16) input_samples <- mkSizedFIFOF(128);

  FIFOF#(Vector#(64, C16)) output_symbols <- mkFIFOF;

  Reg#(Bit#(32)) input_number <- mkReg(0);

  // Keep track of the last 80 samples
  Integer input_buffer_length = 80;
  Reg#(C16) input_buffer[input_buffer_length];
  for (Integer i=0; i < input_buffer_length; i = i + 1) begin
    input_buffer[i] <- mkReg(0);
  end

  Action deq_input_samples = action
    correlator.push(input_samples.first);
    input_buffer[0] <= input_samples.first;
    for (Integer i=1; i < input_buffer_length; i = i + 1) input_buffer[i] <= input_buffer[i-1];
    input_number <= input_number + 1;
    input_samples.deq;
  endaction;

  Reg#(Synchronizer_State) state <- mkReg(Idle);

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // Schmidl & Cox algorithm based coarse synchronization:
  //
  // The short training symbol is a symbol of 16 samples repeated 10 times, so the algorithm work by
  // computing the correlation between `X(t-16*9...t)` and `X(t-16*10...t-16)`. Each times we see
  // a peak of this metric we known that we observed such a symbol during the previous 160 samples.
  //
  // Let `Y(t)` be `X(t) * X(t-16).conjugate()`, I compute this correlation by accumulating the sum
  // of the last 144=16*9 values of `Y` using a shift register.
  //
  // In addition I compute the sum of the norm of the last 144*16*9 samples and compare the previous
  // metric: if the ratio of the previous metric by this norm is too low, this means that I'am just
  // looking at noise currently.
  /////////////////////////////////////////////////////////////////////////////////////////////////
  Reg#(C16) accumulator_y <- mkReg(0);
  Reg#(F16) accumulator_z <- mkReg(0);
  ShiftReg#(C16) buffer_x_16 <- mkShiftReg(16, constFn(0));
  ShiftReg#(F16) buffer_z_144 <- mkShiftReg(16*9, constFn(0));
  ShiftReg#(C16) buffer_y_144 <- mkShiftReg(16*9, constFn(0));
  F16 y_z_threshold = 0.4;

  Integer peak_length = 8;
  Reg#(F16) peak_detector[peak_length*2+1];
  for (Integer i=0; i < peak_length*2+1; i = i + 1) peak_detector[i] <- mkReg(0);

  rule schmidl_cox_rl if (state == Idle);
    // Compute X(t) and X(t-16)
    C16 x_t = input_buffer[0];
    C16 x_tm16 = buffer_x_16.first;
    deq_input_samples;

    // Compute Y(t) and Y(t-16*9)
    C16 y_tm144 = buffer_y_144.first;
    C16 y_t = x_t * cmplxConj(x_tm16);
    accumulator_y <= accumulator_y + y_t - y_tm144;

    // Compute Z(t) and Z(t-16*9)
    F16 z_tm144 = buffer_z_144.first;
    F16 z_t = (x_t * cmplxConj(x_t)).rel;
    accumulator_z <= accumulator_z + z_t - z_tm144;

    // Update the shift registers
    buffer_z_144.push(z_t);
    buffer_y_144.push(y_t);
    buffer_x_16.push(x_t);

    // Compute the norm of sum Y(t) and sum Z(t) for peak detection
    F16 z_norm = accumulator_z * accumulator_z;
    F16 y_norm = (accumulator_y * cmplxConj(accumulator_y)).rel;

    // Compare the power of Y and Z: low power peaks are not considered valids
    if (y_norm > z_norm * y_z_threshold) begin
      // Peak detection algorithm
      Bool is_peak = True;
      for (Integer i=0; i < peak_length; i = i + 1) begin
        if (peak_detector[i] > peak_detector[peak_length]) is_peak = False;
        if (peak_detector[peak_length+1+i] > peak_detector[peak_length]) is_peak = False;
      end

      if (is_peak) begin
        state <= WaitForLts;
        $display("found peak at %d", input_number);
      end
    end

    peak_detector[2*peak_length] <= y_norm;
    for (Integer i=0; i < 2*peak_length; i = i + 1) begin
      peak_detector[i] <= peak_detector[i+1];
    end

    //color_graph(0, 0, 0);
    //draw_graph(input_number, signExtend(pack(y_norm)), 456000/250, 65536*2);
  endrule

  /////////////////////////////////////////////////////////////////////////////////////////////////
  // Long training symbol synchronization:
  // Now that we found the approximate time of the end of the short training symbols, we can start
  // to search for the set of samples that maximize the correlation with the expected long training
  // symbol. Doing so we can find a more precise estimation of the begining of a symbol.
  /////////////////////////////////////////////////////////////////////////////////////////////////

  Reg#(Bit#(20)) best_correlation <- mkReg(0);
  Reg#(Bit#(32)) best_correlation_delay <- mkReg(0);
  Reg#(Bit#(32)) lts_delay <- mkReg(0);
  Integer lts_sync_range = 10;

  rule lts_sync if (state == WaitForLts);
    deq_input_samples;

    if (correlator.result > best_correlation) begin
      best_correlation <= correlator.result;
      best_correlation_delay <= lts_delay;
    end


    if (lts_delay == fromInteger(16 * 5 - peak_length + lts_sync_range)) begin
      $display("best correlation time: %d", input_number - lts_delay + best_correlation_delay);
      $display("time: %d", input_number);
      lts_delay <= lts_delay + 1 - best_correlation_delay;
      state <= Lts;
    end else begin

      lts_delay <= lts_delay + 1;
    end
  endrule

  rule lts2 if (state == Lts);
    lts_delay <= lts_delay == 80 ? 0 : lts_delay + 1;
    deq_input_samples;

    if (lts_delay == 0) begin
      $display("view symbol at number: %d", input_number);
      Vector#(64, C16) out = newVector;
      for (Integer i=0; i < 64; i = i + 1) begin
        out[i] = input_buffer[63 - i];
      end

      output_symbols.enq(out);
    end
  endrule

  method put_sample = input_samples.enq;
  method Action back_to_idle;
    best_correlation <= 0;
    lts_delay <= 0;
    state <= Idle;
  endmethod
  method ActionValue#(Vector#(64,C16)) get_ofdm_symbol = toGet(output_symbols).get;
endmodule

module mkNumericOscilator#(Bit#(32) frequency, Bit#(32) sample_rate) (Get#(C16));
  Reg#(Bit#(32)) phase <- mkReg(0);

  method ActionValue#(C16) get;
    // Update oscilator phase
    phase <= phase + frequency < sample_rate ? phase + frequency : phase + frequency - sample_rate;

    if (4 * phase < 1 * sample_rate) return cmplx(1,1);
    else if (4 * phase < 2 * sample_rate) return cmplx(-1,1);
    else if (4 * phase < 3 * sample_rate) return cmplx(-1,-1);
    else return cmplx(1,-1);
  endmethod
endmodule

(* synthesize *)
module mkTestSynchronizer(Empty);
  RegFile#(Bit#(32), F16) samples <- mkRegFileLoad("samples.hex", 0, 465000);
  Reg#(Bit#(32)) sample_num <- mkReg(0);

  let synchronizer <- mkSynchronizer;
  let fft_64 <- mkStreamFFT64;

  Reg#(C16) signal <- mkReg(0);
  Get#(C16) oscilator <- mkNumericOscilator(2000, 44100);

  Reg#(Bit#(32)) down_sampler <- mkReg(0);

  Reg#(Maybe#(Vector#(64, C16))) correction_symbol <- mkReg(Invalid);

  rule from_fft;
    Vector#(64,C16) freq = fft_64.response;
    fft_64.deq;

    //if (correction_symbol matches tagged Valid .x) begin
    //  for (Integer i=0; i < 64; i = i + 1) freq[i] = freq[i] * x[i];
    //end else begin
    //  Vector#(64,C16) x = newVector;
    //  for (Integer i=0; i < 64; i = i + 1) x[i] = lts_frequencies[i] / freq[i];
    //  correction_symbol <= Valid(x);
    //end

    //$display("\n=== frequencies ===");
    //for (Integer i=0; i < valueof(64); i = i + 1) begin
    //  $write("%d: rel: ", i);
    //  fxptWrite(7, freq[i].rel);
    //  $write(" img: ");
    //  fxptWrite(7, freq[i].img);
    //  $display();
    //end
  endrule

  rule synchronizer_to_fft;
    let symbol <- synchronizer.get_ofdm_symbol;
    fft_64.enq(symbol);
    $display("\n=== symbol ===");
    for (Integer i=0; i < valueof(64); i = i + 1) begin
      $write("%d: rel: ", i);
      fxptWrite(7, symbol[i].rel);
      $write(" img: ");
      fxptWrite(7, symbol[i].img);
      $display();
    end
  endrule

  mkAutoFSM(seq
      render_graph();
      while (sample_num < 465000) action
        F16 sample = samples.sub(sample_num);
        sample_num <= sample_num + 1;

        F16 alpha = 0.005;
        C16 carrier_approx <- oscilator.get;
        C16 x = cmplx(sample, 0) * carrier_approx;
        signal <= signal * cmplx(1-alpha,0) + cmplx(alpha,0) * x;

        color_graph(0, 0, 255);
        draw_graph(sample_num, signExtend(pack(signal.rel)), 456000, 65536*2);
        color_graph(255, 0, 0);
        draw_graph(sample_num, signExtend(pack(signal.img)), 456000, 65536*2);

        if (down_sampler == 250) begin
          synchronizer.put_sample(signal);
          down_sampler <= 0;
        end else begin
          down_sampler <= down_sampler+1;
        end
      endaction
      render_graph();

      $display("finish");
      while (True) noAction;
  endseq);

endmodule
