#!/usr/bin/env python3
"""Writes test/fixtures/add_one.onnx: one Add node, y = x + 1, float32
[1, 3]. The ONNX protobuf is encoded by hand so no onnx package is needed.

    python3 -I tool/make_add_one.py
"""
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


def tensor_type(dims):
    shape = b"".join(msg(1, num(1, d)) for d in dims)
    return msg(1, num(1, 1) + msg(2, shape))  # elem_type FLOAT, shape


def value_info(name, dims):
    return text(1, name) + msg(2, tensor_type(dims))


node = text(1, "x") + text(1, "one") + text(2, "y") + text(3, "add") + text(4, "Add")
one = num(1, 1) + num(2, 1) + msg(4, struct.pack("<f", 1.0)) + text(8, "one")
graph = (
    msg(1, node)
    + text(2, "add_one")
    + msg(5, one)
    + msg(11, value_info("x", [1, 3]))
    + msg(12, value_info("y", [1, 3]))
)
model = num(1, 8) + text(2, "submersion-test") + msg(7, graph) + msg(8, text(1, "") + num(2, 13))

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test", "fixtures", "add_one.onnx")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "wb") as fh:
    fh.write(model)
print(path, len(model), "bytes")
