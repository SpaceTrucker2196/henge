import jwt, time, json, sys, urllib.request, urllib.parse, os
KEY_ID="H3U2MJCD77"; ISSUER="69a6de84-cb86-47e3-e053-5b8c7c11a4d1"
KEY=os.path.expanduser("~/.private_keys/AuthKey_%s.p8"%KEY_ID)
priv=open(KEY).read()
def token():
    now=int(time.time())
    return jwt.encode({"iss":ISSUER,"iat":now,"exp":now+1200,"aud":"appstoreconnect-v1"},
                      priv, algorithm="ES256", headers={"kid":KEY_ID,"typ":"JWT"})
T=token()
def get(path, params=None):
    url="https://api.appstoreconnect.apple.com/v1/"+path
    if params: url += "?"+urllib.parse.urlencode(params, doseq=True)
    if path.startswith("http"): url=path
    r=urllib.request.Request(url, headers={"Authorization":"Bearer "+T})
    try:
        with urllib.request.urlopen(r) as f: return json.load(f)
    except urllib.error.HTTPError as e:
        return {"__error__": e.code, "body": e.read().decode()[:600]}
if __name__=="__main__":
    print(json.dumps(get(sys.argv[1], json.loads(sys.argv[2]) if len(sys.argv)>2 else None), indent=1)[:3000])
