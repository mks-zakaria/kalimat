import sys, json, time, base64, subprocess, urllib.request, urllib.error, os
KEY=os.path.expanduser('~/.appstoreconnect/private_keys/AuthKey_FRT72JC9WV.p8'); KID='FRT72JC9WV'; ISS='c8bca885-6780-4d7c-9b6a-494f61367030'
def b64(b): return base64.urlsafe_b64encode(b).rstrip(b'=')
def token():
    h=b64(json.dumps({'alg':'ES256','kid':KID,'typ':'JWT'}).encode()); now=int(time.time())
    p=b64(json.dumps({'iss':ISS,'iat':now,'exp':now+1100,'aud':'appstoreconnect-v1'}).encode())
    msg=h+b'.'+p
    der=subprocess.run(['openssl','dgst','-sha256','-sign',KEY],input=msg,capture_output=True,check=True).stdout
    # DER -> raw r||s
    i=3+ (1 if der[1]&0x80 else 0); 
    def rd(off):
        assert der[off]==2; l=der[off+1]; v=der[off+2:off+2+l]; return v.lstrip(b'\0').rjust(32,b'\0'), off+2+l
    off=2 if not der[1]&0x80 else 3
    r,off=rd(off); s,_=rd(off)
    return (msg+b'.'+b64(r+s)).decode()
def api(method, path, body=None):
    url=path if path.startswith('http') else 'https://api.appstoreconnect.apple.com'+path
    req=urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization':'Bearer '+token(),'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(req) as r:
            t=r.read(); return r.status, (json.loads(t) if t else None)
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b'null')
if __name__=='__main__':
    st,j=api(sys.argv[1], sys.argv[2], json.loads(sys.argv[3]) if len(sys.argv)>3 else None)
    print(st); print(json.dumps(j,ensure_ascii=False,indent=1)[:6000])
