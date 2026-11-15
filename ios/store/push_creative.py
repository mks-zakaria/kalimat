#!/usr/bin/env python3
"""Uploads store/creative/{header,search}-{ar,en}.png into the app's asset library and places them as
the product page header and search results asset of the ar-SA / en-US listing (iOS 27+ creative
assets). Found by probing the API: appAssetLibraryImages (category CREATIVE_ASSETS, relationship
assetLibrary) → appAssetLibraryPlacements (placementType + image + appStoreVersionLocalization)."""
import hashlib, json, os, sys, urllib.request
sys.path.insert(0, os.path.dirname(__file__))
from asc_api import api
APP = "6835100780"
HERE = os.path.dirname(os.path.abspath(__file__))
FILES = {("ar-SA", "PRODUCT_PAGE_HEADER_ASSET"): "header-ar.png", ("ar-SA", "APP_STORE_SEARCH_RESULTS_ASSET"): "search-ar.png",
         ("en-US", "PRODUCT_PAGE_HEADER_ASSET"): "header-en.png", ("en-US", "APP_STORE_SEARCH_RESULTS_ASSET"): "search-en.png"}

def die(what, st, j): print("FAIL", what, st, json.dumps(j, ensure_ascii=False)[:900]); sys.exit(1)

st, j = api("GET", f"/v1/apps/{APP}/appStoreVersions")
version = j["data"][0]["id"]
st, j = api("GET", f"/v1/appStoreVersions/{version}/appStoreVersionLocalizations")
locs = {d["attributes"]["locale"]: d["id"] for d in j["data"]}

for (locale, ptype), fname in FILES.items():
    # skip if this localization already has that placement
    st, j = api("GET", f"/v1/appStoreVersionLocalizations/{locs[locale]}/placements?limit=200")
    if any(p["attributes"]["placementType"] == ptype for p in j.get("data", [])):
        print("skip", locale, ptype); continue
    data = open(os.path.join(HERE, "creative", fname), "rb").read()
    name = f"{locale}-{fname}"
    # reuse an image already sent under this name (an earlier run that stopped half-way)
    st, j = api("GET", f"/v1/appAssetLibraries/{APP}/images?limit=200")
    old = next((d for d in j.get("data", []) if d["attributes"]["fileName"] == name), None)
    if old:
        iid, ops = old["id"], []
    else:
        st, j = api("POST", "/v1/appAssetLibraryImages", {"data": {"type": "appAssetLibraryImages",
            "attributes": {"fileName": name, "fileSize": len(data), "category": "CREATIVE_ASSETS"},
            "relationships": {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": APP}}}}})
        if st >= 300: die("reserve " + fname, st, j)
        iid, ops = j["data"]["id"], j["data"]["attributes"].get("uploadOperations") or []
    for op in ops:
        part = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=part, method=op["method"],
                                     headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        urllib.request.urlopen(req).read()
    st, j = api("PATCH", f"/v1/appAssetLibraryImages/{iid}", {"data": {"type": "appAssetLibraryImages", "id": iid,
        "attributes": {"uploaded": True}}})
    if st >= 300: die("commit " + fname, st, j)
    st, j = api("POST", "/v1/appAssetLibraryPlacements", {"data": {"type": "appAssetLibraryPlacements",
        "attributes": {"placementType": ptype},
        "relationships": {"image": {"data": {"type": "appAssetLibraryImages", "id": iid}},
                          "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": locs[locale]}}}}})
    if st >= 300: die("place " + fname, st, j)
    print("placed", locale, ptype, fname, "->", j["data"]["attributes"].get("state"))
