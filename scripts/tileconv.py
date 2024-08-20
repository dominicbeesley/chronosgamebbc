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
	bpp = 1
	try:
		opts, args = getopt.getopt(argv,"h2",["bpp2"])
	except getopt.GetoptError as e:
		usage(fh=sys.stderr, msg=f"ERROR:Parameter error: {e}", exit=1)
		
	for opt, arg in opts:
		if opt == '-h':
			usage(exit=0)
		elif opt == '-2':
			bpp = 2

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
			odata = bytearray(stride_in * height * bpp)		
			for r in range(height):
				for c in range(stride_in):
					d = data[o + c + r * stride_in]
					if bpp == 1:
						odata[(r % 8) + (c * 8) + (stride_in * 8 * (r // 8))] = d
					if bpp == 2:
						oa = (r % 8) + (c * 8 * bpp) + (stride_in * 8 * bpp * (r // 8))
						d2 = morebpp(d, bpp)
						odata[oa] = d2 >> 8
						odata[oa+8] = d2 & 0xFF

			fo.write(odata)
			o = o + stride_in * height
	finally:
		fo.close()

def morebpp(d, bpp):
	r = 0
	s = 8 // bpp
	m = (1 << s) - 1	
	ss = 0
	for n in range(bpp):
		for b in range(bpp):
			r = r | ((d & m) << ss)
			ss = ss + s
		d = d >> s
	return r

if __name__ == "__main__":
	main(sys.argv[1:])