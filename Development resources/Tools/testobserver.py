#!/usr/bin/env python

import socket


s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(('0.0.0.0', 5555))
s.listen(1)

conn, addr = s.accept()
print 'Connection address:', addr
while 1:
    data = conn.recv(1024)
    if not data: break
    print "received data:", data
conn.close()