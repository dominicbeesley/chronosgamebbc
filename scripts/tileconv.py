#!/usr/bin/env python3
# convert tiles in spectrum col minor format to bbc char cells

import sys,getopt

def usage(fh=sys.stdout, msg=None, exit=None):
	if msg:
		print(msg, file=fh)

	print("tileconv.py <in> <out>")

	if exit:
		sys.exit(exit);


def main(argv):
	inputfile = ''
	outputfile = ''
	try:
		opts, args = getopt.getopt(argv,"hi:o:",["ifile=","ofile="])
	except getopt.GetoptError as e:
		usage(fh=sys.stderr, msg=f"ERROR:Parameter error: {e}", exit=1)
		
	for opt, arg in opts:
		if opt == '-h':
			usage(exit=0)

	if len(args)<2:
		usage(fh=sys.stderr, msg="Too few arguments", exit=1)
	
	try:
		fo = open(args[1], 'wb')
	except Exception as e:
		usage(fh=sys.stderr, msg=f"Error opening output file {args[1] : {e}}", exit=2)
	try:
		#load entire file to a binary variable (max 64k)
		try:
			with open(args[0], 'rb') as f:
				data = f.read(0x10000);
		except Exception as e:
			usage(fh=sys.stderr, msg=f"Error opening {args[0]} and reading data: {e}", exit=2)

		#assumes 16x16 pixel tiles in col minor 

		ntiles = len(data) // 32
		print(f"Processing {ntiles} tiles of 16x16 pixels")

		stride_in=2
		height=16

		o = 0
		for c in range(ntiles):
			odata = bytearray(stride_in * height)		
			for r in range(height):
				for c in range(stride_in):
					odata[(r % 8) + (c * 8) + (stride_in * 8 * (r // 8))] = data[o + c + r * stride_in]

			fo.write(odata)
			o = o + stride_in * height
	finally:
		fo.close()



if __name__ == "__main__":
	main(sys.argv[1:])