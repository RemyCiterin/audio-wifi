import FixedPoint::*;
import Complex::*;

typedef 64 FFT_SIZE;

typedef FixedPoint#(16,16) F16;
typedef Complex#(F16) C16;

typedef enum {
  BPSK = 1,
  QPSK = 2,
  QAM16 = 4,
  QAM64 = 6
} Modulation deriving(Bits, Eq, FShow);

typedef enum {
  RATE_6MBPS = 'b1011,
  RATE_9MBPS = 'b1111,
  RATE_12MBPS = 'b1010,
  RATE_18MBPS = 'b1110,
  RATE_24MBPS = 'b1001,
  RATE_36MBPS = 'b1101,
  RATE_48MBPS = 'b1000,
  RATE_54MBPS = 'b1100
} DataRate deriving(Bits, Eq, FShow);

typedef enum {
  PUNCTURING_1_2 = 6,
  PUNCTURING_2_3 = 8,
  PUNCTURING_3_4 = 9
} Puncturing deriving(Bits, Eq, FShow);

typedef Bit#(12) Length;

typedef 127 PILOT_WIDTH;
Bit#(PILOT_WIDTH) pilot_reset = 'he275a0abd218d4cf928b9bbf6cb08f;

function Puncturing puncturing_from_rate(DataRate rate);
  return case (rate) matches
    RATE_6MBPS: PUNCTURING_1_2;
    RATE_9MBPS: PUNCTURING_3_4;
    RATE_12MBPS: PUNCTURING_1_2;
    RATE_18MBPS: PUNCTURING_3_4;
    RATE_24MBPS: PUNCTURING_1_2;
    RATE_36MBPS: PUNCTURING_3_4;
    RATE_48MBPS: PUNCTURING_2_3;
    RATE_54MBPS: PUNCTURING_3_4;
  endcase;
endfunction

function Modulation modulation_from_rate(DataRate rate);
  return case (rate) matches
    RATE_6MBPS: BPSK;
    RATE_9MBPS: BPSK;
    RATE_12MBPS: QPSK;
    RATE_18MBPS: QPSK;
    RATE_24MBPS: QAM16;
    RATE_36MBPS: QAM16;
    RATE_48MBPS: QAM64;
    RATE_54MBPS: QAM64;
  endcase;
endfunction

function Integer coded_bits_per_subcarier(DataRate rate);
  return case (rate) matches
    RATE_6MBPS: 1;
    RATE_9MBPS: 1;
    RATE_12MBPS: 2;
    RATE_18MBPS: 2;
    RATE_24MBPS: 4;
    RATE_36MBPS: 4;
    RATE_48MBPS: 6;
    RATE_54MBPS: 6;
  endcase;
endfunction

function Integer coded_bits_per_ofdm(DataRate rate);
  return coded_bits_per_subcarier(rate) * 48;
endfunction

function Integer data_bits_per_ofdm(DataRate rate);
  return case (rate) matches
    RATE_6MBPS: 24;
    RATE_9MBPS: 36;
    RATE_12MBPS: 48;
    RATE_18MBPS: 72;
    RATE_24MBPS: 96;
    RATE_36MBPS: 144;
    RATE_48MBPS: 192;
    RATE_54MBPS: 216;
  endcase;
endfunction
