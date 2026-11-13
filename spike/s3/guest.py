import subprocess, sys, time, os, socket, re
T='/Users/dp/Repository/tars-linux'
extra=sys.argv[1].split() if sys.argv[1] else []
cmds=sys.argv[2:]
sock='ser.sock'
if os.path.exists(sock): os.remove(sock)
p=subprocess.Popen(['qemu-system-x86_64','-m','2G','-kernel',T+'/kernel/build/arch/x86/boot/bzImage','-initrd','initrd-plus.cpio','-append','console=ttyS0','-vga','none','-device','virtio-gpu-pci','-display','none','-serial','unix:'+sock+',server,nowait','-monitor','none','-no-reboot']+extra,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
time.sleep(1)
s=socket.socket(socket.AF_UNIX); s.connect(sock); s.settimeout(1)
buf=b''
log=open('serial2.log','wb')
def pump(pattern,timeout):
    global buf
    end=time.time()+timeout; start=len(buf)
    while time.time()<end:
        try:
            d=s.recv(65536)
            if d: buf+=d; log.write(d); log.flush()
        except socket.timeout: pass
        if pattern and re.search(pattern, buf[start:]): return True
    return False
print('boot:',pump(rb'terminal: screen> root@tars',120))
time.sleep(1)
for i,c in enumerate(cmds):
    start=len(buf)
    s.sendall((c+f'; echo XMARK{i}_$status\r').encode())
    ok=pump((f'XMARK{i}_\\d').encode(), float(os.environ.get('CMD_TIMEOUT','240')))
    out=buf[start:].decode('utf-8','replace')
    # 터미널 진단 줄(terminal: ...)은 뺀다
    lines=[l for l in out.splitlines() if not l.startswith('terminal: ')]
    print(f'--- cmd {i}: {c} (finished={ok})'); print('\n'.join(lines)[-int(os.environ.get("TAIL","6000")):])
p.kill()
