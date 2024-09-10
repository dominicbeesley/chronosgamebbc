#!/usr/bin/env python3
# grab data from spectrum rom and make a chunky number font by shifting and or'ing the font with itself

FONT_BASE=0x3D00

import sys,getopt,re

def usage(fh=sys.stdout, msg=None, exit=None):
	if msg:
		print(msg, file=fh)

	print("""numfont.py <in> <out>
	""")

	if exit:
		sys.exit(exit);


def main(argv):

	try:
		opts, args = getopt.gnu_getopt(argv,'',
			[''])
	except getopt.GetoptError as e:
		usage(fh=sys.stderr, msg=f"ERROR:Parameter error: {e}", exit=1)
		
	for opt, arg in opts:
		usage(fh=sys.stderr, msg=f"Unexpected option {opt}", exit=1)

	if len(args)<2:
		usage(fh=sys.stderr, msg="Too few arguments", exit=1)

	#load entire file to a binary variable (max 64k)
	try:
		with open(args[0], 'rb') as f:
			data = f.read(0x10000);
	except Exception as e:
		usage(fh=sys.stderr, msg=f"Error opening {args[0]} and reading data: {e}", exit=2)

	try:
		fo = open(args[1], 'wb')
	except Exception as e:
		usage(fh=sys.stderr, msg=f"Error opening output file {args[1] : {e}}", exit=2)
	try:
		arr = bytearray([0] * (10*8))

		for i in range(10*8):
			x = data[FONT_BASE + 8*16 + i]
			x = (x >> 1) | x

			arr[i] = x

		fo.write(arr)

	finally:
		fo.close();


if __name__ == "__main__":
	main(sys.argv[1:])
