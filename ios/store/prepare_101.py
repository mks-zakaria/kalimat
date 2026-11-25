"""Kalimat 1.0.1: create the version, set What's New, attach build 2, upload the App Preview videos.

    python3 prepare_101.py        (idempotent: re-running skips what is already done)

The version only carries the App Preview videos (Apple accepts previews only on a version being prepared);
the game is unchanged, and What's New says so. Retries on the flaky connection. The owner presses Submit.
"""
import hashlib, json, time, urllib.request
from pathlib import Path
import asc_api as a

APP, VERSION, BUILD = "6835100780", "1.0.1", "3"
HERE = Path(__file__).parent
PREVIEWS = {"ar-SA": HERE.parent / "tools/promo/previews/kalimat-preview-ar.mp4",
            "en-US": HERE.parent / "tools/promo/previews/kalimat-preview-en.mp4"}
WHATS_NEW = {"ar-SA": "تحديث صيانة بسيط. اللعب كما هو: ٢٥٠ لغزًا بين الكلمات المتقاطعة والكلمات المخفية، ومعدل ذكاء يتحدّث بعد كل لغز.",
             "en-US": "Maintenance update. Gameplay is unchanged: 250 crosswords and word searches, and an IQ score that updates after every puzzle."}

def api(method, path, body=None, ok=(200, 201, 204)):
    for i in range(8):
        try:
            st, j = a.api(method, path, body)
            if st in ok: return j
            if st >= 500: raise RuntimeError(st)
            raise SystemExit(f"{method} {path} -> {st} {json.dumps(j)[:600]}")
        except SystemExit: raise
        except Exception as e:
            print("  retry", i + 1, type(e).__name__, flush=True); time.sleep(6 * (i + 1))
    raise SystemExit("network keeps failing")

def version_id():
    for v in api("GET", f"/v1/apps/{APP}/appStoreVersions?limit=10")["data"]:
        if v["attributes"]["versionString"] == VERSION: return v["id"]
    v = api("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": VERSION},
        "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]
    print("created version", VERSION, v["attributes"]["appStoreState"]); return v["id"]

def put(op, chunk):
    for i in range(8):
        try:
            r = urllib.request.Request(op["url"], data=chunk, method=op["method"])
            for h in op.get("requestHeaders", []): r.add_header(h["name"], h["value"])
            with urllib.request.urlopen(r, timeout=300) as resp: resp.read(); return
        except Exception as e:
            print("  retry chunk", i + 1, type(e).__name__, flush=True); time.sleep(6 * (i + 1))
    raise SystemExit("upload keeps failing")

def upload_preview(loc_id, path):
    for ptype in ["IPHONE_67", "IPHONE_65"]:
        sets = api("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appPreviewSets")["data"]
        sid = next((s["id"] for s in sets if s["attributes"]["previewType"] == ptype), None) or api("POST", "/v1/appPreviewSets",
            {"data": {"type": "appPreviewSets", "attributes": {"previewType": ptype},
             "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}})["data"]["id"]
        for p in api("GET", f"/v1/appPreviewSets/{sid}/appPreviews")["data"]:
            if p["attributes"]["fileName"] == path.name:
                if (p["attributes"].get("assetDeliveryState") or {}).get("state") in ("COMPLETE", "UPLOAD_COMPLETE"):
                    print("  ", ptype, "already there"); break
                api("DELETE", f"/v1/appPreviews/{p['id']}")
        else:
            blob = path.read_bytes()
            r = api("POST", "/v1/appPreviews", {"data": {"type": "appPreviews",
                "attributes": {"fileName": path.name, "fileSize": len(blob), "mimeType": "video/mp4", "previewFrameTimeCode": "00:00:01:00"},
                "relationships": {"appPreviewSet": {"data": {"type": "appPreviewSets", "id": sid}}}}})["data"]
            for op in r["attributes"]["uploadOperations"]: put(op, blob[op["offset"]:op["offset"] + op["length"]])
            api("PATCH", f"/v1/appPreviews/{r['id']}", {"data": {"type": "appPreviews", "id": r["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
            print("  ", ptype, "uploaded", path.name, flush=True)

def main():
    vid = version_id()
    locs = {l["attributes"]["locale"]: l["id"] for l in api("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]}
    print("locales:", ", ".join(locs))
    for loc, lid in locs.items():
        text = WHATS_NEW.get(loc) or WHATS_NEW["en-US"]
        api("PATCH", f"/v1/appStoreVersionLocalizations/{lid}", {"data": {"type": "appStoreVersionLocalizations", "id": lid,
            "attributes": {"whatsNew": text}}})
    print("whatsNew set")
    for loc, path in PREVIEWS.items():
        if loc in locs: print(loc); upload_preview(locs[loc], path)
    for i in range(40):
        b = api("GET", f"/v1/builds?filter[app]={APP}&filter[version]={BUILD}&filter[preReleaseVersion.version]={VERSION}&limit=1")["data"]
        if b and b[0]["attributes"]["processingState"] == "VALID": break
        print("  build", BUILD, b[0]["attributes"]["processingState"] if b else "not visible yet", flush=True); time.sleep(30)
    api("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": b[0]["id"]}})
    v = api("GET", f"/v1/appStoreVersions/{vid}?include=build,appStoreReviewDetail")
    inc = {x["type"]: x["attributes"] for x in v.get("included", [])}
    print("version", VERSION, v["data"]["attributes"]["appStoreState"], "| build", inc.get("builds", {}).get("version"),
          "| review contact", bool(inc.get("appStoreReviewDetails", {}).get("contactEmail")))

if __name__ == "__main__":
    main()
