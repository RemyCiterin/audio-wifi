interface Scrambler#(numeric type n);
  (* always_ready *)
  method Bool canEnq;
  method Action enq(Bit#(n) in);

  (* always_ready *)
  method Bool valid;
  method Action deq;
  method Bit#(n) response;
endinterface

module mkScrambler(Scrambler#(n));
  Reg#(Bool) idle[2] <- mkCReg(2, True);
  Reg#(Bit#(n)) data <- mkRegU;

  Reg#(Bit#(7)) state <- mkReg('b1111111);

  Bit#(n) out = data;
  Bit#(7) st = state;

  for (Integer i=0; i < valueof(n); i = i + 1) begin
    Bit#(1) x = st[0] ^ st[3];
    st = {x, truncateLSB(st)};
    out[i] = out[i] ^ x;
  end

  method canEnq = idle[1];
  method Action enq(Bit#(n) in) if (idle[1]);
    idle[1] <= False;
    data <= in;
  endmethod

  method valid = !idle[0];
  method response;
    Bit#(n) out = data;
    Bit#(7) st = state;

    for (Integer i=0; i < valueof(n); i = i + 1) begin
      Bit#(1) x = st[0] ^ st[3];
      st = {x, truncateLSB(st)};
      out[i] = out[i] ^ x;
    end

    return out;
  endmethod

  method Action deq;
    idle[0] <= True;
    state <= st;
  endmethod
endmodule
