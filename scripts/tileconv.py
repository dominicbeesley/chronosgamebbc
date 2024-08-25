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
	--count|-n
		Number of tiles to capture default=1
	--offset|-o
		Offset in file default=0
	--bpp2|-2
		2 bits per pixel mode
	--mask|-m XX	
		set colour AND mask
	--xor|-x XX   
		set colour XOR
	--stride|-s n
		set stride in bytes default=2
	--width|-w n
		set width in bytes default=2
	--height|-h n
		set height in pixels default=16
	--linear
		export as column minor
		""")

	if exit:
		sys.exit(exit);

def myint(s:str):
	if (s.startswith('$')):
		return int(s[1:],16)
	elif (s.startswith('0x')):
		return int(s[2:],16)
	else:
		return int(s)


def main(argv):
	bpp = 1
	mask = 0xFF
	xor  = 0x00
	stride = 2
	width = 2
	height = 16
	ntiles = 1
	o = 0
	linear = False
	try:
		opts, args = getopt.gnu_getopt(argv,'h2m:x:n:o:s:w:h:l',
			['help','bpp2','mask=','xor=','count=','offset=','stride=','width=','height=','linear'])
	except getopt.GetoptError as e:
		usage(fh=sys.stderr, msg=f"ERROR:Parameter error: {e}", exit=1)
		
	for opt, arg in opts:
		if opt == '-h' or opt == '--help':
			usage(exit=0)
		elif opt == '-2' or opt == '--bpp2':
			bpp = 2
		elif opt == '-l' or opt == '--linear':
			linear = True
		elif opt == '-m' or opt == '--mask':
			try:
				mask = myint(arg)	
			except:
				usage(fh=sys.stderr, msg=f"Bad mask value: {arg}", exit=1)	
		elif opt == '-x' or opt == '--xor':
			try:
				xor = myint(arg)	
			except:
				usage(fh=sys.stderr, msg=f"Bad xor value: {arg}", exit=1)	
		elif opt == '-s' or opt == '--stride':
			try:
				stride = myint(arg)	
			except:
				usage(fh=sys.stderr, msg=f"Bad stride value: {arg}", exit=1)	
		elif opt == '-w' or opt == '--width':
			try:
				width = myint(arg)	
				stride = width
			except:
				usage(fh=sys.stderr, msg=f"Bad width value: {arg}", exit=1)	
		elif opt == '-h' or opt == '--height':
			try:
				height = myint(arg)	
			except:
				usage(fh=sys.stderr, msg=f"Bad height value: {arg}", exit=1)	
		elif opt == '-n' or opt == '--count':
			try:
				ntiles = myint(arg)	
			except:
				usage(fh=sys.stderr, msg=f"Bad count value: {arg}", exit=1)	
		elif opt == '-o' or opt == '--offset':
			try:
				o = myint(arg)	
			except:
				usage(fh=sys.stderr, msg=f"Bad offset value: {arg}", exit=1)	
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


		for c in range(ntiles):
			if linear:
				odata = bytearray(width * height * bpp)		
				for r in range(height):
					for c in range(width):
						d = data[o + c + r * stride]
						oa = (r * width + c) * bpp
						if bpp == 1:
							odata[oa] = (d & mask) ^ xor
						if bpp == 2:
							d2 = morebpp(d, bpp)
							odata[oa] = ((d2 >> 8) & mask) ^ xor
							odata[oa+1] = ((d2 & 0xFF) & mask) ^ xor
			else:
				odata = bytearray(width * 8*(height // 8) * bpp)		
				for r in range(height):
					for c in range(width):
						d = data[o + c + r * stride]
						if bpp == 1:
							odata[(r % 8) + (c * 8) + (width * 8 * (r // 8))] = (d & mask) ^ xor
						if bpp == 2:
							oa = (r % 8) + (c * 8 * bpp) + (width * 8 * bpp * (r // 8))
							d2 = morebpp(d, bpp)
							odata[oa] = ((d2 >> 8) & mask) ^ xor
							odata[oa+8] = ((d2 & 0xFF) & mask) ^ xor

			fo.write(odata)
			o = o + stride * height
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