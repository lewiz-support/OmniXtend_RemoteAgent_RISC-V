#****************************************************************
# December 6, 2022
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#****************************************************************

import sys
import argparse

parser = argparse.ArgumentParser(
                    prog = 'byte_flip.py',
                    description = 'Reverses endianness of bytes in a binary file. File is divided into words and bytes are reversed in each word. Word order is unchanged.',
                    epilog = ' ')

parser.add_argument('file', help='Input file name')
parser.add_argument('-w', '--word-size', dest='wsize', type=int, default=8, help='File is divided into words of this size (Default=8)')
parser.add_argument('-b', '--byte-size', dest='bsize', type=int, default=1, help='Keep this many bytes together when reversing (Default=1)')
parser.add_argument('-z', '--zero-pad', metavar='bytes', type=int, default=0, help='Pad the end of file with this many zero bytes (Default=0)')
parser.add_argument('-o', '--output', help='Output file name (Optional)')

args = parser.parse_args()
if not args.output:
    args.output = args.file + '.flip.dat'


with open(args.output, "wb") as file_out:
    with open(args.file, "rb") as file_in:
        word = b''
        byte = file_in.read(args.bsize)
        bnum = 0
        
        #Read bytes from input file and write every <word-size> in reverse order
        while byte:
            # Do stuff with byte.
            word = byte + word
            bnum += 1
            if bnum >= args.wsize:

                file_out.write(word)
                bnum = 0
                word = b''
            byte = file_in.read(args.bsize)
            
        #If file is not a multiple of <word-size>, output the partial last word with padding
        if bnum:
            file_out.write(bytes(args.bsize*(args.wsize-bnum))+word)

    if args.zero_pad:
        file_out.write(bytes(args.zero_pad))

