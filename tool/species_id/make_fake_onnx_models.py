#!/usr/bin/env python3
"""Writes the fake detector and classifier the ONNX engine's real-runtime
test loads (test/features/species_id/data/onnx/fixtures/): ONNX models whose
outputs are constants, so the worker isolate, the bindings and the pipeline
run end to end through real ONNX Runtime without a real pack.

- fake_detector.onnx: input [1, 3, 8, 8]; outputs boxes [1, 1, 4] (one box,
  centre 0.5, 0.5, size 0.5) and logits [1, 1, 1] (a probability of 0.9).
- fake_classifier.onnx: input [1, 3, 4, 4]; output embedding [1, 3] = 1, 2, 3.

The protobuf is encoded by hand so no onnx package is needed:

    python3 -I tool/species_id/make_fake_onnx_models.py
"""
import math
import os
import struct


def varint(n):
    out = b""
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out += bytes([b | 0x80])
        else:
            return out + bytes([b])


def field(number, wire, payload):
    return varint(number << 3 | wire) + payload


def num(number, value):
    return field(number, 0, varint(value))


def msg(number, body):
    return field(number, 2, varint(len(body)) + body)


def text(number, value):
    return msg(number, value.encode())


def tensor(name, dims, values):
    floats = b"".join(struct.pack("<f", v) for v in values)
    return b"".join(num(1, d) for d in dims) + num(2, 1) + msg(4, floats) + text(8, name)


def value_info(name, dims):
    shape = b"".join(msg(1, num(1, d)) for d in dims)
    return text(1, name) + msg(2, msg(1, num(1, 1) + msg(2, shape)))


def constant(output, dims, values):
    # AttributeProto: name 1, t 5, type 20 (TENSOR is 4).
    attribute = text(1, "value") + msg(5, tensor(output, dims, values)) + num(20, 4)
    return text(2, output) + text(4, "Constant") + msg(5, attribute)


def model(name, input_dims, outputs):
    graph = b"".join(msg(1, constant(o, d, v)) for o, d, v in outputs)
    graph += text(2, name) + msg(11, value_info("image", input_dims))
    graph += b"".join(msg(12, value_info(o, d)) for o, d, _ in outputs)
    return num(1, 8) + text(2, "submersion-test") + msg(7, graph) + msg(8, text(1, "") + num(2, 13))


here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "..", "test", "features", "species_id", "data", "onnx", "fixtures")
os.makedirs(out, exist_ok=True)
logit = math.log(0.9 / 0.1)
files = {
    "fake_detector.onnx": model(
        "fake_detector",
        [1, 3, 8, 8],
        [("boxes", [1, 1, 4], [0.5, 0.5, 0.5, 0.5]), ("logits", [1, 1, 1], [logit])],
    ),
    "fake_classifier.onnx": model(
        "fake_classifier", [1, 3, 4, 4], [("embedding", [1, 3], [1.0, 2.0, 3.0])]
    ),
}
for name, data in files.items():
    with open(os.path.join(out, name), "wb") as fh:
        fh.write(data)
    print(name, len(data), "bytes")
