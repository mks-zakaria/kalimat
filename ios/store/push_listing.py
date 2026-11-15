#!/usr/bin/env python3
"""Pushes the App Store listing for Kalimat from listing.json through the App Store Connect API.
Idempotent: re-running PATCHes the same values. Needs the API key in ~/.appstoreconnect.

    python3 store/push_listing.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from asc_api import api

APP = "6835100780"
HERE = os.path.dirname(os.path.abspath(__file__))
L = json.load(open(os.path.join(HERE, "listing.json")))
VERSION = "1.0.0"

def ok(st, j, what):
    if st >= 300:
        print("FAIL", what, st, json.dumps(j, ensure_ascii=False)[:600]); sys.exit(1)
    print("ok  ", what)

def get(path): st, j = api("GET", path); ok(st, j, "GET " + path); return j

info = next(d for d in get(f"/v1/apps/{APP}/appInfos")["data"]
            if d["attributes"].get("state") in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "WAITING_FOR_REVIEW", None))["id"]
version = next(d for d in get(f"/v1/apps/{APP}/appStoreVersions")["data"]
               if d["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"))["id"]

# version string + copyright
ok(*api("PATCH", f"/v1/appStoreVersions/{version}", {"data": {"type": "appStoreVersions", "id": version,
    "attributes": {"versionString": VERSION, "copyright": L["copyright"]}}}), "version " + VERSION)

# app info localizations (name, subtitle, privacy URL)
locs = {d["attributes"]["locale"]: d["id"] for d in get(f"/v1/appInfos/{info}/appInfoLocalizations")["data"]}
for locale in ("ar-SA", "en-US"):
    attrs = {"name": L[locale]["name"], "subtitle": L[locale]["subtitle"], "privacyPolicyUrl": L["urls"]["privacy"]}
    if locale in locs:
        ok(*api("PATCH", f"/v1/appInfoLocalizations/{locs[locale]}", {"data": {"type": "appInfoLocalizations",
            "id": locs[locale], "attributes": attrs}}), f"app info {locale}")
    else:
        ok(*api("POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations",
            "attributes": {"locale": locale, **attrs},
            "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info}}}}}), f"app info {locale} (new)")

# version localizations (re-fetch: creating an app-info localization auto-creates these)
vlocs = {d["attributes"]["locale"]: d["id"] for d in get(f"/v1/appStoreVersions/{version}/appStoreVersionLocalizations")["data"]}
for locale in ("ar-SA", "en-US"):
    d = L[locale]
    attrs = {"description": d["description"], "keywords": d["keywords"], "promotionalText": d["promotionalText"],
             "supportUrl": L["urls"]["support"], "marketingUrl": L["urls"]["marketing"]}
    if locale in vlocs:
        ok(*api("PATCH", f"/v1/appStoreVersionLocalizations/{vlocs[locale]}", {"data": {"type": "appStoreVersionLocalizations",
            "id": vlocs[locale], "attributes": attrs}}), f"version text {locale}")
    else:
        ok(*api("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations",
            "attributes": {"locale": locale, **attrs},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version}}}}}), f"version text {locale} (new)")

# categories: Games › Word + Puzzle
c = L["category"]
ok(*api("PATCH", f"/v1/appInfos/{info}", {"data": {"type": "appInfos", "id": info, "relationships": {
    "primaryCategory": {"data": {"type": "appCategories", "id": c["primary"]}},
    "primarySubcategoryOne": {"data": {"type": "appCategories", "id": c["primarySub1"]}},
    "primarySubcategoryTwo": {"data": {"type": "appCategories", "id": c["primarySub2"]}}}}}), "category Games › Word, Puzzle")

# content rights: only our own content (font under SIL OFL)
ok(*api("PATCH", f"/v1/apps/{APP}", {"data": {"type": "apps", "id": APP,
    "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}}), "content rights")

# age rating: a word game with ads, nothing else
NONE = "NONE"
rating = {k: NONE for k in ["alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
    "horrorOrFearThemes", "matureOrSuggestiveThemes", "medicalOrTreatmentInformation", "profanityOrCrudeHumor",
    "sexualContentGraphicAndNudity", "sexualContentOrNudity", "violenceCartoonOrFantasy", "violenceRealistic",
    "violenceRealisticProlongedGraphicOrSadistic"]}
rating.update({"advertising": True, "gambling": False, "lootBox": False, "messagingAndChat": False,
    "parentalControls": False, "ageAssurance": False, "unrestrictedWebAccess": False, "userGeneratedContent": False,
    "healthOrWellnessTopics": False, "socialMedia": False})
ok(*api("PATCH", f"/v1/ageRatingDeclarations/{info}", {"data": {"type": "ageRatingDeclarations", "id": info,
    "attributes": rating}}), "age rating")

print("listing pushed for", APP, "version", version)
