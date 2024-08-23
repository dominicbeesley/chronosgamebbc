#!/usr/bin/env python3
# convert tiles in spectrum col minor format to bbc char cells

import sys,getopt

def usage(fh=sys.stdout, msg=None, exit=None):
	if msg:
		print(msg, file=fh)

	print("""tileconv.py [options] <in> <out>
OPTIONS:
	--help|-h	
		Display this help message
	--bpp2|-2
		2 bits per pixel mode
	--mask|-m XX	
		set colour AND mask
	--xor|-x XX   
		set colour XOR
		""")

	if exit:
		sys.exit(exit);


def main(argv):
	bpp = 1
	mask = 0xFF
	xor  = 0x00
	try:
		opts, args = getopt.gnu_getopt(argv,'h2m:x:',['help','bpp2','mask=','xor='])
	except getopt.GetoptError as e:
		usage(fh=sys.stderr, msg=f"ERROR:Parameter error: {e}", exit=1)
		
	for opt, arg in opts:
		if opt == '-h' or opt == '--help':
			usage(exit=0)
		elif opt == '-2' or opt == '--bpp2':
			bpp = 2
		elif opt == '-m' or opt == '--mask':
			try:
				mask = int(arg, 16)	
			except:
				usage(fh=sys.stderr, msg=f"Bad mask value", exit=1)	
		elif opt == '-x' or opt == '--xor':
			try:
				xor = int(arg, 16)	
			except:
				usage(fh=sys.stderr, msg=f"Bad xor value", exit=1)	
		else:
			usage(fh=sys.stderr, msg=f"Unexpected option {opt}", exit=1)

	if len(args)<2:
		usage(fh=sys.stderr, msg="Too few arguments", exit=1)

	print(bpp)

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
						odata[(r % 8) + (c * 8) + (stride_in * 8 * (r // 8))] = (d & mask) ^ xor
					if bpp == 2:
						oa = (r % 8) + (c * 8 * bpp) + (stride_in * 8 * bpp * (r // 8))
						d2 = morebpp(d, bpp)
						odata[oa] = ((d2 >> 8) & mask) ^ xor
						odata[oa+8] = ((d2 & 0xFF) & mask) ^ xor

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