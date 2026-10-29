# Indonesia Coffee Chain Wars – Neo4j graph package

**Original data (your CSV):** 13,000 rows, 5 brands, 16 cities. Every original row is kept as a `Snapshot` node
(same ID as `store_transaction_id`); only the long `cot_retail_dynamics_rationale` text and `confidence_score` were dropped.

**Everything else is SYNTHETIC** (generated with a fixed seed, so it is reproducible). Do not present it as real market data.

## What was generated, and how it ties to your data
| Added | How it was built |
|---|---|
| `Outlet` (2,928) | Your rows grouped by brand + city + format + beans + amenities; each group split into outlets of ~6 snapshots. Outlet-level attributes are therefore consistent with your data. |
| Dates | Each outlet gets 1-6 monthly snapshots between Nov 2025 and Oct 2026, a `NEXT` chain, opening dates, and ~3% closed outlets. |
| Geography | 61 districts (real names, approximate/synthetic coordinates) and 976 POIs (office towers, malls, universities, transit, hospitals, residential). Office-lobby / mall-kiosk outlets are placed at an office tower / mall. |
| `NEAR_COMPETITOR` / `NEAR_SAME_BRAND` | Computed from the synthetic coordinates (<= 500 m). Spread was tuned per city to approximate your `competitor_density_500m`; rows were assigned to outlets by density rank so the two agree (correlation ~0.51, geometric mean 6.3 vs 5.1 in the original). |
| Operators | Company-operated vs franchisee/licensee operators (Pareto-sized portfolios). All are single-brand. |
| Delivery platforms | GrabFood / GoFood / ShopeeFood links with dummy commission, rating and prep time. |
| Products and promotions | 10 generic products with brand-level prices; 240 monthly promotions. Each snapshot with a discount is linked to the same-brand promo that month closest to its `discount_voucher_pct`. |
| Customers (6,000) | Fully synthetic: district, segment, loyalty tier, visits per outlet (preferring outlets near home), and 1,068 brand-`SwitchEvent`s. Switch direction follows the driver (price drivers go to cheaper brands, WiFi to brands with more WiFi, queue to app-heavy brands, taste to better-rated brands). |

## Graph model
```
(Customer)-[:VISITED {visits,total_spend_idr,first/last_visit}]->(Outlet)
(Customer)-[:HAD_SWITCH]->(SwitchEvent)-[:FROM_BRAND|TO_BRAND]->(Brand)
(SwitchEvent)-[:CAUSED_BY]->(SwitchDriver)   (SwitchEvent)-[:LEFT_OUTLET|JOINED_OUTLET]->(Outlet)
(Outlet)-[:OF_BRAND]->(Brand)   (Outlet)-[:IN_DISTRICT]->(District)-[:IN_CITY]->(City)
(Outlet)-[:NEAR_COMPETITOR|NEAR_SAME_BRAND {distance_m}]-(Outlet)
(Outlet)-[:NEAR_POI]->(POI)   (Outlet)-[:OPERATED_BY]->(Operator)   (Outlet)-[:LISTED_ON]->(DeliveryPlatform)
(Outlet)-[:HAS_FORMAT|USES_BEANS|OFFERS_AMENITY]->(...)
(Outlet)-[:HAS_SNAPSHOT]->(Snapshot)-[:NEXT]->(Snapshot)
(Snapshot)-[:PRIMARY_SEGMENT|DOMINANT_ORDER_METHOD|DOMINANT_LOYALTY|AT_RISK_OF]->(...)
(Snapshot)-[:AFFECTED_BY]->(Promotion)<-[:RUNS]-(Brand)   (Brand)-[:OFFERS {list_price_idr}]->(Product)
```

## Files
19 CSVs (nodes + relationships), `import.cypher` (constraints + `LOAD CSV`), `queries.cypher` (8 demo queries).

## Known limitations
- `import.cypher` has not been run against a live Neo4j instance here; expect to fix small syntax or path issues.
- Segment, order method, loyalty tier and switch driver stay at snapshot level (as in your data) because they vary per row.
- Competitor density is approximate; per-outlet geometry will not exactly match every original value.
