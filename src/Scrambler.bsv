typedef Bit#(7) State;

typedef 24 DATA_WIDTH;
typedef Bit#(DATA_WIDTH) Data;

interface Scrambler;
  method Action put(Data in);
  method ActionValue#(Data) get;
endinterface

function Tuple2#(Bit#(n), State) transitions(State state, Bit#(n) data);
  for (Integer i=0; i < valueof(n); i = i + 1) begin
    Bit#(1) x = state[0] ^ state[3];
    state = {x, truncateLSB(state)};
    data[i] = data[i] ^ x;
  end

  return tuple2(data, state);
endfunction

(* synthesize *)
module mkScrambler(Scrambler);
  Reg#(Bool) valid <- mkReg(False);
  Reg#(Data) data <- mkRegU;

  Reg#(State) state <- mkReg('b1111111);

  method Action put(Data in) if (!valid);
    valid <= True;
    data <= in;
  endmethod

  method ActionValue#(Data) get if (valid);
    match {.out, .new_state} = transitions(state, data);
    state <= new_state;
    valid <= False;
    return out;
  endmethod
endmodule

interface DeScrambler;
  method Action put(Bool rst, Data bits);
  method ActionValue#(Data) get;
endinterface

(* synthesize *)
module mkDeScrambler(DeScrambler);
  Reg#(Bool) valid <- mkReg(False);
  Reg#(Data) data <- mkRegU;
  Reg#(Bool) rst <- mkRegU;

  Reg#(State) state <- mkReg('1);

  // Search the states of the scrambling FSM in (up-to) 127 cycles
  rule search if (valid && rst);
    if (transitions(state, data[6:0]).fst == 0) rst <= False;
    else state <= transitions(state, 1'b0).snd;
  endrule

  method Action put(Bool r, Data d) if (!valid);
    valid <= True;
    data <= d;
    rst <= r;
  endmethod

  method ActionValue#(Data) get if (valid && !rst);
    match {.out, .new_state} = transitions(state, data);
    state <= new_state;
    valid <= False;
    return out;
  endmethod
endmodule
