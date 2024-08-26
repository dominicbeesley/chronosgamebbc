#!/usr/bin/env python3
# convert tiles in spectrum col minor format to bbc char cells

import sys,getopt,re

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
	--linear|-l
		export as column minor
	--default|-d
		default bits - this will be used for destination data shifted in 
		during permutes or for the extra rows in a non-linear output
		when height % 8 != 0
	--permute|-p
		append all permutations of the tile shifted within a byte
		ie. for a 2bpp sprite the original sprite will be output
		followed by the same sprite shifted 1, 2 and 3 pixels
		A parameter should be supplied that specified
		L|R - 	left or right, the sprite will be shifted left or
			right
		I|E -   in-place or expand, an extra byte will be added to
			shift into otherwise pixels will be lost
		I|A -   interleave or append, interleave the new sprites
			will be added in place, else each shifted set will
			be appended
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

class Permute:
	act:False
	left:True
	inPlace:True
	interleve:True

def main(argv):
	bpp = 1
	mask = 0xFF
	xor  = 0x00
	stride = 2
	width = 2
	height = 16
	ntiles = 1
	default = 0
	o = 0
	linear = False
	permute = None

	try:
		opts, args = getopt.gnu_getopt(argv,'h2m:x:n:o:s:w:h:lp:d:',
			['help','bpp2','mask=','xor=','count=','offset=','stride=','width=','height=','linear','permute=','default='])
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
		elif opt == '-d' or opt == '--default':
			try:
				default = myint(arg)
			except:
				usage(fh=sys.stderr, msg=f"Bad default value: {arg}", exit=1)	
		elif opt == '-p' or opt == '--permute':
			try:
				m = re.match(r"^\s*(L|R)(I|E)(I|A)\s*$", arg)
				if not m:
					raise "Bad permute string"
				permute = Permute()
				permute.act = True
				permute.left = m.group(1) == 'L'
				permute.inPlace = m.group(2) == 'I'
				permute.interleave = m.group(3) == 'I'
			except Exception as e:
				usage(fh=sys.stderr, msg=f"Bad permute string: {arg}", exit=1)	
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

		w1 = 1 if permute and not permute.inPlace else 0	# extra byte in output for shift
		widtho = w1 + (width * bpp)
		po = 8 // bpp if permute and not permute.interleave else 1	#permute outer count
		pi = 8 // bpp if permute and permute.interleave else 1		#permute inner count
		heighto = ((height + 7) // 8) * 8


		print(str(permute))
		print(str(po))
		print(str(pi))
		print("%d x %d" % (widtho,heighto))

		for pa in range(po):
			for t in range(ntiles):
				for pb in range(pi):
					odata = bytearray([default] * (widtho * heighto))
					for r in range(height):
						oo = o + r * stride
						rowdata_in = data[oo:oo + width]
						rowdata_out = bytearray([default] * widtho)
						for c in range(width):
							d = rowdata_in[c]
							oa = (c * bpp)
							if bpp == 1:
								rowdata_out[oa] = (d & mask) ^ xor
							elif bpp == 2:
								d2 = morebpp(d, bpp)
								rowdata_out[oa] = ((d2 >> 8) & mask) ^ xor
								rowdata_out[oa+1] = ((d2 & 0xFF) & mask) ^ xor
						
						#permute
						if permute and pa+pb > 0 and len(rowdata_out) > 1:
							s = default
							if permute.left:
								for i in reversed(range(len(rowdata_out))):
									(s, rowdata_out[i]) = shift_left(rowdata_out[i], s, pa+pb, bpp)
							else:
								for i in range(len(rowdata_out)):
									(rowdata_out[i], s) = shift_right(s, rowdata_out[i], pa+pb, bpp)

						# rearrange for linear / character cell
						if linear:
							oa = (r * widtho)
							for x in range(len(rowdata_out)):
								odata[oa + x * 8] = rowdata_out[x]
						else:
							oa = (r % 8) + (widtho * 8 * (r // 8))
							for x in range(len(rowdata_out)):
								odata[oa + x * 8] = rowdata_out[x]
					fo.write(odata)
				o = o + stride * height
	finally:
		fo.close()

def shift_left(a,b,n,bpp):
	for i in range(n):
		if bpp == 1:
			x = a & 0x80
			a = (a << 1) | ((b & 0x80) >>7)
			b = (b << 1) | ((x & 0x80) >>7)
		elif bpp == 2:
			x = a & 0x88
			a = ((a << 1) & 0xEE) | ((b & 0x88) >>3)
			b = ((b << 1) & 0xEE) | ((x & 0x88) >>3)
	a = a << ((8 // bpp) - n)
	return (b,a)

def shift_right(a,b,n,bpp):
	for i in range(n):
		if bpp == 1:
			x = b & 1
			b = (b >> 1) | ((a & 1) <<7)
			a = (a >> 1) | ((x & 1) <<7)
		elif bpp == 2:
			x = b & 0x11
			b = ((b >> 1) & 0x77) | ((a & 0x11) <<3)
			a = ((a >> 1) & 0x77) | ((x & 0x11) <<3)
	a = a >> ((8 // bpp) - n)
	return (b,a)


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