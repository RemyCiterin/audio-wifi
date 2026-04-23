from constants import *
import numpy as np
import constants
import sys

class ConvEncoder:
    """
    The convolutional encoder use the polynomes 0o171 and 0o133 to generate an output
    stream of up to 48 bits for each 24 bits of input. The encoder is reset at the
    begining of each packet.
    """
    def __init__(self):
        self.state = [0,0,0,0,0,0]
        self.puncturing = None
        self.data = None

        self.puncturing_a = None
        self.puncturing_b = None

    def run(self, reset_to_rate, data):
        """
        Run the encoder finite state machine on a list of bits

        Arguments
        ---------
        reset_to_rate:
            Contains an integer if we want to reset the finite state machine to a given
            rate. Or None if we don't want to reset it.
        data:
            List of bits to encode.

        Returns
        -------
            A list of encoded bits, up to two times bigger than the input (depending on
            the choosen rate)
        """
        if reset_to_rate is not None:
            self.puncturing = constants.puncturing_from_rate(reset_to_rate)
            (self.puncturing_a, self.puncturing_b) = constants.puncturing_mask(self.puncturing)
            self.state = [0,0,0,0,0,0]

        out = []
        for i in range(len(data)):
            x = [data[i]] + self.state
            a = x[0]        ^ x[2] ^ x[3] ^ x[5] ^ x[6]
            b = x[0] ^ x[1] ^ x[2] ^ x[3]        ^ x[6]
            self.state = x[:6]

            if self.puncturing_a[0] == 1: out.append(a)
            if self.puncturing_b[0] == 1: out.append(b)
            self.puncturing_a = self.puncturing_a[1:] + [self.puncturing_a[0]]
            self.puncturing_b = self.puncturing_b[1:] + [self.puncturing_b[0]]

        return out

class ViterbiDecoder:
    """
    The viterbi decoder is in chage of decoding packets from the convolutional encoder,
    the decoder take as input a reset signal (with the new encoding rate in case of a
    reset), and a sequence of 32, 36, or 48 bits depending on the rate, and returns the
    24 bits that the sequence represent.
    """
    def __init__(self):
        self.puncturing_a = None
        self.puncturing_b = None
        self.puncturing = None
        self.state = []

        self.trellis = []
        for _ in range(24):
            self.trellis.append([])
            for _ in range(2 ** 6):
                self.trellis[-1].append(0)

        self.old_costs = []
        self.new_costs = []
        for _ in range(64):
            self.new_costs.append(0)
            self.old_costs.append(0)

    def compute_step(x):
        assert(len(x) == 7)
        a = x[0]        ^ x[2] ^ x[3] ^ x[5] ^ x[6]
        b = x[0] ^ x[1] ^ x[2] ^ x[3]        ^ x[6]
        return (a, b)

    def compute_transition_output(prev_state, next_state):
        """
        Given an input and an output state representing a transition of the encoder,
        returns the two output bits produced by the transition.
        """
        assert(len(prev_state) == 6)
        assert(len(next_state) == 6)
        x = next_state + [prev_state[5]]
        return ViterbiDecoder.compute_step(x)

    def compute_prev_state(state, i):
        """
        At each transition, the encoder forget one bit of the previous state, this
        function take the destination state of the transition and the last bit of the
        previous state, and compute it.
        """
        assert(len(state) == 6)
        return state[1:] + [i]

    def state_to_int(state: list[int]) -> int:
        out = 0
        for i in range(6):
            out |= state[i] << i
        return out

    def int_to_state(x: int) -> list[int]:
        out = []
        for i in range(6):
            out.append(x >> i & 1)
        return out

    def iter_states():
        for i in range(2 ** 6):
            yield ViterbiDecoder.int_to_state(i)

    def run(self, reset_to_rate, data):
        """
        Run the encoder finite state machine on a list of bits

        Arguments
        ---------
        reset_to_rate:
            Contains an integer if we want to reset the finite state machine to a given
            rate. Or None if we don't want to reset it.
        data:
            List of bits to decode of size 32, 36 or 48 bits depending on the
            data rate.

        Returns
        -------
            The decoded bits
        """
        if reset_to_rate is not None:
            self.puncturing = constants.puncturing_from_rate(reset_to_rate)
            (self.puncturing_a, self.puncturing_b) = constants.puncturing_mask(self.puncturing)
            for i in range(64): self.old_costs[i] = 0 if i == 0 else 65536
            self.state = [0,0,0,0,0,0]

            if reset_to_rate == constants.RATE_9MBPS:
                print("WARNING: 9Mb/s is not supported by the Viterbi decoder", file=sys.stderr)
                return None

        #############################################################################
        # Read the inputs and insert dummy bits using the puncturing sequence
        #############################################################################
        a = []
        b = []
        a_dummy = []
        b_dummy = []
        data_index = 0

        for i in range(24):
            if self.puncturing_a[0] == 1:
                a.append(data[data_index])
                a_dummy.append(0)
                data_index += 1
            else:
                a_dummy.append(1)
                a.append(0)

            if self.puncturing_b[0] == 1:
                b.append(data[data_index])
                b_dummy.append(0)
                data_index += 1
            else:
                b_dummy.append(1)
                b.append(0)

            self.puncturing_a = self.puncturing_a[1:] + [self.puncturing_a[0]]
            self.puncturing_b = self.puncturing_b[1:] + [self.puncturing_b[0]]

        assert(len(data) == data_index)

        for i in range(24):
            for state in ViterbiDecoder.iter_states():
                s0 = ViterbiDecoder.compute_prev_state(state, 0)
                s1 = ViterbiDecoder.compute_prev_state(state, 1)
                (a0, b0) = ViterbiDecoder.compute_transition_output(s0, state)
                (a1, b1) = ViterbiDecoder.compute_transition_output(s1, state)

                cost0 = ((a0 ^ a[i]) & ~a_dummy[i]) + ((b0 ^ b[i]) & ~b_dummy[i])
                cost0 += self.old_costs[ViterbiDecoder.state_to_int(s0)]

                cost1 = ((a1 ^ a[i]) & ~a_dummy[i]) + ((b1 ^ b[i]) & ~b_dummy[i])
                cost1 += self.old_costs[ViterbiDecoder.state_to_int(s1)]

                if cost0 < cost1:
                    self.trellis[i][ViterbiDecoder.state_to_int(state)] = s0
                    self.new_costs[ViterbiDecoder.state_to_int(state)] = cost0
                else:
                    self.trellis[i][ViterbiDecoder.state_to_int(state)] = s1
                    self.new_costs[ViterbiDecoder.state_to_int(state)] = cost1

            tmp = self.old_costs
            self.old_costs = self.new_costs
            self.new_costs = tmp

        cost = 65536
        for state in ViterbiDecoder.iter_states():
            if self.old_costs[ViterbiDecoder.state_to_int(state)] < cost:
                cost = self.old_costs[ViterbiDecoder.state_to_int(state)]
                self.state = state

        state = ViterbiDecoder.state_to_int(self.state)
        out = np.zeros((24,), dtype=int)
        for i in range(24):
            out[23-i] = state & 1
            state = ViterbiDecoder.state_to_int(self.trellis[23-i][state])

        return out
