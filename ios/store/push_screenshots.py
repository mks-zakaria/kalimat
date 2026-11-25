#!/usr/bin/env python3
"""Uploads store/screenshots-ar/*.png to the 6.9" slot (APP_IPHONE_67) of the ar-SA listing.
Other sets: push_screenshots.py <SLOT> <folder under store/>, e.g.
  APP_IPAD_PRO_3GEN_129 ipad-ar/13-inch     APP_IPHONE_DUO duo-ar
Idempotent: a file whose name is already in the set is skipped. Order = file name order."""
import glob, hashlib, json, os, sys, urllib.request
sys.path.insert(0, os.path.dirname(__file__))
from asc_api import api
APP, LOCALE = "6835100780", "ar-SA"
SLOT = sys.argv[1] if len(sys.argv) > 1 else "APP_IPHONE_67"
FOLDER = sys.argv[2] if len(sys.argv) > 2 else "screenshots-ar"
HERE = os.path.dirname(os.path.abspath(__file__))

st, j = api("GET", f"/v1/apps/{APP}/appStoreVersions")
version = next(d["id"] for d in j["data"] if d["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"))
st, j = api("GET", f"/v1/appStoreVersions/{version}/appStoreVersionLocalizations")
loc = next(d["id"] for d in j["data"] if d["attributes"]["locale"] == LOCALE)
st, j = api("GET", f"/v1/appStoreVersionLocalizations/{loc}/appScreenshotSets")
sset = next((d["id"] for d in j["data"] if d["attributes"]["screenshotDisplayType"] == SLOT), None)
if not sset:
    st, j = api("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
        "attributes": {"screenshotDisplayType": SLOT},
        "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc}}}}})
    sset = j["data"]["id"]
st, j = api("GET", f"/v1/appScreenshotSets/{sset}/appScreenshots")
have = {d["attributes"]["fileName"]: d["id"] for d in j["data"]}

ids = []
for path in sorted(glob.glob(os.path.join(HERE, FOLDER, "*.png"))):
    name = os.path.basename(path)
    if name in have:
        print("skip", name); ids.append(have[name]); continue
    data = open(path, "rb").read()
    st, j = api("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
        "attributes": {"fileName": name, "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset}}}}})
    if st >= 300: print("reserve failed", name, json.dumps(j)[:400]); sys.exit(1)
    sid = j["data"]["id"]
    for op in j["data"]["attributes"]["uploadOperations"]:
        part = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=part, method=op["method"],
                                     headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        urllib.request.urlopen(req).read()
    st, j = api("PATCH", f"/v1/appScreenshots/{sid}", {"data": {"type": "appScreenshots", "id": sid,
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print("uploaded", name, st)
    ids.append(sid)

st, j = api("PATCH", f"/v1/appScreenshotSets/{sset}/relationships/appScreenshots",
            {"data": [{"type": "appScreenshots", "id": i} for i in ids]})
print("order pinned:", st)
