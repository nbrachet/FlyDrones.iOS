#!/usr/bin/env python

import socket
import time

from argparse import ArgumentParser
parser = ArgumentParser(description=__doc__)
parser.add_argument("--filename", help="path to file", action='append')
args = parser.parse_args()
filename = args.filename[0]

def bytes_from_file(filename):
    with open(filename, "rb") as f:
        while True:
            byte = f.read(1)
            if not byte:
                break
            yield(ord(byte))


class App():
    def __init__(self, filename):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.bind(('0.0.0.0', 5556))
        s.listen(1)
        conn, addr = s.accept()
        print 'Connection address:', addr

        with open(filename) as f:
            for line in f:
                print(line, '/n')
                conn.send(line)
                time.sleep(0.1)

        conn.close()

app=App(filename)