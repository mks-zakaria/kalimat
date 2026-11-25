#!/usr/bin/env python3
"""Free price + available in every territory, for Kalimat. Run once (creating twice returns 409)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from asc_api import api
APP = "6835100780"

st, j = api("GET", f"/v1/apps/{APP}/appPricePoints?filter[territory]=USA&limit=200")
free = next(p["id"] for p in j["data"] if p["attributes"]["customerPrice"] in ("0.0", "0", "0.00"))
st, j = api("POST", "/v1/appPriceSchedules", {"data": {"type": "appPriceSchedules", "relationships": {
    "app": {"data": {"type": "apps", "id": APP}},
    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
    "manualPrices": {"data": [{"type": "appPrices", "id": "${price1}"}]}}},
    "included": [{"type": "appPrices", "id": "${price1}", "attributes": {"startDate": None},
                  "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free}}}}]})
print("price free:", st, "" if st < 300 else json.dumps(j)[:400])

st, j = api("GET", "/v1/territories?limit=200")
terr = [t["id"] for t in j["data"]]
inc = [{"type": "territoryAvailabilities", "id": "${t-%s}" % t, "attributes": {"available": True},
        "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for t in terr]
st, j = api("POST", "/v2/appAvailabilities", {"data": {"type": "appAvailabilities",
    "attributes": {"availableInNewTerritories": True},
    "relationships": {"app": {"data": {"type": "apps", "id": APP}},
                      "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": i["id"]} for i in inc]}}},
    "included": inc})
print(f"availability ({len(terr)} territories):", st, "" if st < 300 else json.dumps(j)[:400])
