#!/usr/bin/env python3
"""Audit the App Store Connect record for review readiness."""
import jwt, time, json, os, urllib.request, urllib.parse, urllib.error

KEY_ID="H3U2MJCD77"; ISSUER="69a6de84-cb86-47e3-e053-5b8c7c11a4d1"
APP_ID="6798126839"
priv=open(os.path.expanduser(f"~/.private_keys/AuthKey_{KEY_ID}.p8")).read()
now=int(time.time())
T=jwt.encode({"iss":ISSUER,"iat":now,"exp":now+1200,"aud":"appstoreconnect-v1"},
             priv, algorithm="ES256", headers={"kid":KEY_ID,"typ":"JWT"})

def get(path, params=None):
    url = path if path.startswith("http") else "https://api.appstoreconnect.apple.com/v1/"+path
    if params: url += ("&" if "?" in url else "?")+urllib.parse.urlencode(params, doseq=True)
    r=urllib.request.Request(url, headers={"Authorization":"Bearer "+T})
    try:
        with urllib.request.urlopen(r) as f: return json.load(f)
    except urllib.error.HTTPError as e:
        return {"__error__":e.code,"body":e.read().decode()[:300]}

OK, BAD, WARN = "PASS", "BLOCK", "WARN"
rows=[]
def row(status, item, detail): rows.append((status,item,detail))

# ---- versions
vs=get(f"apps/{APP_ID}/appStoreVersions", {"limit":5})
if "__error__" in vs: row(BAD,"App Store version", vs["body"]); ver=None
else:
    ver = vs["data"][0] if vs["data"] else None
if ver:
    a=ver["attributes"]
    row(OK if a["appStoreState"]=="PREPARE_FOR_SUBMISSION" else WARN,
        "Version record", f"{a['versionString']} · {a['appStoreState']} · {a['platform']} · release={a.get('releaseType')}")
    VID=ver["id"]

    # build attached
    b=get(f"appStoreVersions/{VID}/build")
    if b.get("data"):
        ba=b["data"]["attributes"]
        row(OK,"Build attached", f"build {ba.get('version')} · {ba.get('processingState')}")
        BID=b["data"]["id"]
        ec=get(f"builds/{BID}")
        row(OK if ec.get("data",{}).get("attributes",{}).get("usesNonExemptEncryption") is not None else BAD,
            "Export compliance", f"usesNonExemptEncryption={ec.get('data',{}).get('attributes',{}).get('usesNonExemptEncryption')}")
    else:
        row(BAD,"Build attached","NO BUILD attached to this version")

    # localizations
    locs=get(f"appStoreVersions/{VID}/appStoreVersionLocalizations",{"limit":50})
    ld=locs.get("data",[])
    row(OK if ld else BAD,"Version localizations", f"{len(ld)} locales")
    missing=[]
    shots={}
    for l in ld:
        la=l["attributes"]; loc=la["locale"]
        gaps=[k for k in ("description","keywords","supportUrl") if not la.get(k)]
        if gaps: missing.append(f"{loc}:{'/'.join(gaps)}")
        ss=get(f"appStoreVersionLocalizations/{l['id']}/appScreenshotSets",{"limit":20})
        types=[s["attributes"]["screenshotDisplayType"] for s in ss.get("data",[])]
        shots[loc]=types
    row(OK if not missing else BAD,"Metadata completeness",
        "all locales have description/keywords/supportUrl" if not missing else "; ".join(missing[:6]))
    en=shots.get("en-US",[])
    row(OK if en else BAD,"Screenshots (en-US)", ", ".join(en) if en else "NONE")
    empty=[k for k,v in shots.items() if not v]
    # Apple falls back to the primary locale, so localized sets are optional, not blocking.
    row(OK if not empty else WARN,"Localized screenshots",
        "every locale has its own" if not empty else f"{len(empty)} locales fall back to en-US: {', '.join(empty[:8])}")

    # review detail
    rd=get(f"appStoreVersions/{VID}/appStoreReviewDetail")
    if rd.get("data"):
        ra=rd["data"]["attributes"]
        need=[k for k in ("contactFirstName","contactLastName","contactPhone","contactEmail") if not ra.get(k)]
        row(OK if not need else BAD,"Review contact",
            "complete" if not need else "missing "+", ".join(need))
        row(OK,"Demo account", f"required={ra.get('demoAccountRequired')}")
        row(OK if ra.get("notes") else WARN,"Review notes", (ra.get("notes") or "none")[:80])
    else:
        row(BAD,"Review detail","NOT CREATED")

    # phased release / IAP attached
    iap=get(f"appStoreVersions/{VID}/appStoreVersionExperiments",{"limit":1})
    
# ---- app info: categories, subtitle, privacy policy
ai=get(f"apps/{APP_ID}/appInfos",{"limit":5})
for info in ai.get("data",[]):
    ia=info["attributes"]
    if ia.get("appStoreState") in ("PREPARE_FOR_SUBMISSION","READY_FOR_DISTRIBUTION"):
        rel=info["relationships"]
        pc=get(f"appInfos/{info['id']}/primaryCategory")
        sc=get(f"appInfos/{info['id']}/secondaryCategory")
        row(OK if pc.get("data") else BAD,"Primary category",
            (pc.get("data") or {}).get("id","NOT SET"))
        row(OK if sc.get("data") else WARN,"Secondary category",
            (sc.get("data") or {}).get("id","not set"))
        il=get(f"appInfos/{info['id']}/appInfoLocalizations",{"limit":50})
        nopriv=[x["attributes"]["locale"] for x in il.get("data",[]) if not x["attributes"].get("privacyPolicyUrl")]
        nosub =[x["attributes"]["locale"] for x in il.get("data",[]) if not x["attributes"].get("subtitle")]
        row(OK if not nopriv else BAD,"Privacy policy URL",
            "all locales" if not nopriv else f"missing in {len(nopriv)}: {', '.join(nopriv[:8])}")
        row(OK if not nosub else WARN,"Subtitle",
            "all locales" if not nosub else f"missing in {len(nosub)}: {', '.join(nosub[:8])}")
        break

# ---- age rating
ard=get(f"apps/{APP_ID}/appInfos",{"limit":5})
for info in ard.get("data",[]):
    a=get(f"appInfos/{info['id']}/ageRatingDeclaration")
    if a.get("data"):
        at=a["data"]["attributes"]
        filled=sum(1 for v in at.values() if v not in (None,))
        row(OK if filled>3 else BAD,"Age rating", f"{filled} fields declared")
        break

# ---- IAP
ip=get(f"apps/{APP_ID}/inAppPurchasesV2",{"limit":10})
for p in ip.get("data",[]):
    pa=p["attributes"]
    st=pa.get("state")
    row(OK if st in ("READY_TO_SUBMIT","APPROVED","WAITING_FOR_REVIEW") else BAD,
        f"IAP {pa.get('productId')}", f"{pa.get('name')} · {st}")
    sc=get("https://api.appstoreconnect.apple.com/v2/inAppPurchases/%s/appStoreReviewScreenshot" % p['id'])
    row(OK if sc.get("data") else BAD, "  IAP review screenshot",
        "present" if sc.get("data") else "MISSING (required for first IAP)")
if not ip.get("data"): row(BAD,"In-app purchase","none found")

# ---- pricing / availability
ps=get(f"apps/{APP_ID}/appPriceSchedule")
row(OK if ps.get("data") else BAD,"Price schedule","set" if ps.get("data") else "NOT SET")
av=get(f"apps/{APP_ID}/appAvailabilityV2")
row(OK if av.get("data") else WARN,"Availability","configured" if av.get("data") else "check territories")

print(f"{'':2} {'CHECK':<28} DETAIL")
print("-"*100)
for s,i,d in rows:
    mark = "OK" if s==OK else ("!!" if s==BAD else " ~")
    print(f"{mark:2} {i:<28} {d}")
blocks=[r for r in rows if r[0]==BAD]
print("-"*100)
print(f"{len(blocks)} blocking, {sum(1 for r in rows if r[0]==WARN)} warnings, {sum(1 for r in rows if r[0]==OK)} pass")
