
def makeheader(length, rate):
    """
    This function compute the SIGNAL field of a message using the coding rate of the
    message and the length of the message. The result is returned as a list of 24 integers
    in the interval {0, 1}, representing the 24 bits of the output field (i-th element
    represent the i-th bit).

    Source
    ------
    Section 17.3.4 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
    """
    translate_rate = []
    for i in range(4):
        translate_rate.append(rate >> i & 1)

    translate_length = []
    for i in range(12):
        translate_length.append(length >> i & 1)

    parity = 0
    for x in translate_rate:
        parity = x ^ parity
    for x in translate_length:
        parity = x ^ parity

    return translate_rate + [0] + translate_length + [parity,0,0,0,0,0,0]

def from_header(header: int):
    """
    This function is in charge of decoding the header received at the begining of a frame,
    it returns the decoded length and rate in case of success, or None in case of a
    failure

    Source
    ------
    Section 17.3.4 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
    """
    rate = header[0:4]
    length = header[5:17]
    parity = header[17]
    tail = header[18:]
    zero = header[4]

    error = zero != 0

    for i in tail:
        error |= i != 0

    for x in rate:
        parity ^= x
    for x in length:
        parity ^= x

    error |= parity != 0

    decoded_rate = 0
    decoded_length = 0

    for i in range(4):
        decoded_rate |= rate[i] << i

    for i in range(12):
        decoded_length |= length[i] << i

    if error:
        return None
    return (decoded_length, decoded_rate)
