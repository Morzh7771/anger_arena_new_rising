import struct,sys,os
d=sys.argv[1]; out=sys.argv[2]; prefix=sys.argv[3]
f=open(d,'rb'); sig,ver,tree=struct.unpack('<III',f.read(12))
if ver==2: f.read(16)
hdr=f.tell()
def cs():
    b=b''
    while (c:=f.read(1))!=b'\0': b+=c
    return b.decode('utf-8','replace')
ents=[]
while (ext:=cs()):
    while (path:=cs()):
        while (name:=cs()):
            crc,pre,ai,off,ln,term=struct.unpack('<IHHIIH',f.read(18))
            predata=f.read(pre)
            full=(path.strip()+'/' if path.strip() else '')+name+'.'+ext
            if full.startswith(prefix): ents.append((full,ai,off,ln,predata))
base=d[:-8]
for full,ai,off,ln,pre in ents:
    if ai==0x7fff: g=open(d,'rb'); g.seek(hdr+tree+off)
    else: g=open(f"{base}_{ai:03d}.vpk",'rb'); g.seek(off)
    data=pre+g.read(ln); p=os.path.join(out,full); os.makedirs(os.path.dirname(p),exist_ok=True); open(p,'wb').write(data)
print(len(ents))
