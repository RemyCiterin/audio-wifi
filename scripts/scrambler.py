from constants import *

class Scrambler:
    """
    The scrambler is in charge of randomizing the bits at the input of the convolutional
    encoder. The inputs and outputs of the scrambler are represented using list of integers
    representing the bits of the integers.

    The initial state of the scrambler must be non-zero but is unspecified as the
    decoder can use the encoded SERVICE field to deduce the initial state of the
    scrambler used to encode the message.
    """
    def __init__(self):
        self.reset = [1,1,1,1,1,1,1]

    def run(self, reset, data):
        if reset:
            self.state = self.reset

        out = []
        for i in range(len(data)):
            bit = self.state[0] ^ self.state[3]
            self.state = self.state[1:7] + [bit]
            out.append(data[i] ^ bit)

        return out

class DeScrambler:
    def __init__(self):
        pass

    def next(state):
        bit = state[0] ^ state[3]
        state = state[1:7] + [bit]
        return (bit, state)

    def sequence(state, length):
        out = []
        for _ in range(length):
            (bit, state) = DeScrambler.next(state)
            out.append(bit)

        return (out, state)

    def run(self, reset, data):
        if reset:
            self.state = [1,1,1,1,1,1,1]

            for _ in range(127):
                (seq, _) = DeScrambler.sequence(self.state, 7)

                stop = True
                for i in range(7):
                    if seq[i] != data[i]:
                        stop = False

                if stop:
                    break

                (_, self.state) = DeScrambler.next(self.state)

        out = []
        for i in range(len(data)):
            (bit, self.state) = DeScrambler.next(self.state)
            out.append(data[i] ^ bit)

        return out
