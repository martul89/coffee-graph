// =====================================================================
// Indonesia Coffee Chain Wars - Neo4j import (Cypher 5)
// Put the CSVs in Neo4j's import directory and run the blocks in order
// (Neo4j Browser / cypher-shell / Workbench). For Aura, replace
// 'file:///' with a public/pre-signed URL base for each CSV.
// Reminder: most of the graph structure is SYNTHETIC - see README.md.
// =====================================================================

// ---------- 0. Constraints ----------
CREATE CONSTRAINT brand_id IF NOT EXISTS FOR (n:Brand) REQUIRE n.brand_id IS UNIQUE;
CREATE CONSTRAINT city_id IF NOT EXISTS FOR (n:City) REQUIRE n.city_id IS UNIQUE;
CREATE CONSTRAINT district_id IF NOT EXISTS FOR (n:District) REQUIRE n.district_id IS UNIQUE;
CREATE CONSTRAINT poi_id IF NOT EXISTS FOR (n:POI) REQUIRE n.poi_id IS UNIQUE;
CREATE CONSTRAINT operator_id IF NOT EXISTS FOR (n:Operator) REQUIRE n.operator_id IS UNIQUE;
CREATE CONSTRAINT outlet_id IF NOT EXISTS FOR (n:Outlet) REQUIRE n.outlet_id IS UNIQUE;
CREATE CONSTRAINT snapshot_id IF NOT EXISTS FOR (n:Snapshot) REQUIRE n.snapshot_id IS UNIQUE;
CREATE CONSTRAINT platform_id IF NOT EXISTS FOR (n:DeliveryPlatform) REQUIRE n.platform_id IS UNIQUE;
CREATE CONSTRAINT product_id IF NOT EXISTS FOR (n:Product) REQUIRE n.product_id IS UNIQUE;
CREATE CONSTRAINT promo_id IF NOT EXISTS FOR (n:Promotion) REQUIRE n.promo_id IS UNIQUE;
CREATE CONSTRAINT customer_id IF NOT EXISTS FOR (n:Customer) REQUIRE n.customer_id IS UNIQUE;
CREATE CONSTRAINT switch_id IF NOT EXISTS FOR (n:SwitchEvent) REQUIRE n.event_id IS UNIQUE;
CREATE CONSTRAINT segment_name IF NOT EXISTS FOR (n:Segment) REQUIRE n.name IS UNIQUE;
CREATE CONSTRAINT format_name IF NOT EXISTS FOR (n:StoreFormat) REQUIRE n.name IS UNIQUE;
CREATE CONSTRAINT bean_name IF NOT EXISTS FOR (n:BeanType) REQUIRE n.name IS UNIQUE;
CREATE CONSTRAINT amenity_name IF NOT EXISTS FOR (n:Amenity) REQUIRE n.name IS UNIQUE;
CREATE CONSTRAINT channel_name IF NOT EXISTS FOR (n:OrderMethod) REQUIRE n.name IS UNIQUE;
CREATE CONSTRAINT loyalty_name IF NOT EXISTS FOR (n:LoyaltyTier) REQUIRE n.name IS UNIQUE;
CREATE CONSTRAINT driver_name IF NOT EXISTS FOR (n:SwitchDriver) REQUIRE n.name IS UNIQUE;
CREATE POINT INDEX outlet_location IF NOT EXISTS FOR (n:Outlet) ON (n.location);
CREATE INDEX snapshot_date IF NOT EXISTS FOR (n:Snapshot) ON (n.snapshot_date);

// ---------- 1. Reference nodes ----------
LOAD CSV WITH HEADERS FROM 'file:///brands.csv' AS row
MERGE (b:Brand {brand_id: row.brand_id})
SET b.name=row.name, b.price_tier=row.price_tier,
    b.avg_base_price_idr=toFloat(row.avg_base_price_idr),
    b.avg_net_price_idr=toFloat(row.avg_net_price_idr),
    b.avg_rating=toFloat(row.avg_rating);

LOAD CSV WITH HEADERS FROM 'file:///cities.csv' AS row
MERGE (c:City {city_id: row.city_id})
SET c.name=row.name, c.location=point({latitude:toFloat(row.center_lat), longitude:toFloat(row.center_lon)});

LOAD CSV WITH HEADERS FROM 'file:///districts.csv' AS row
MERGE (d:District {district_id: row.district_id})
SET d.name=row.name, d.core_weight=toFloat(row.core_weight),
    d.location=point({latitude:toFloat(row.center_lat), longitude:toFloat(row.center_lon)})
WITH d,row MATCH (c:City {city_id:row.city_id}) MERGE (d)-[:IN_CITY]->(c);

LOAD CSV WITH HEADERS FROM 'file:///pois.csv' AS row
MERGE (p:POI {poi_id: row.poi_id})
SET p.name=row.name, p.poi_type=row.poi_type, p.daily_footfall_est=toInteger(row.daily_footfall_est),
    p.location=point({latitude:toFloat(row.lat), longitude:toFloat(row.lon)})
WITH p,row MATCH (d:District {district_id:row.district_id}) MERGE (p)-[:IN_DISTRICT]->(d);

LOAD CSV WITH HEADERS FROM 'file:///operators.csv' AS row
MERGE (o:Operator {operator_id: row.operator_id})
SET o.name=row.name, o.operator_type=row.operator_type;

LOAD CSV WITH HEADERS FROM 'file:///platforms.csv' AS row
MERGE (p:DeliveryPlatform {platform_id: row.platform_id}) SET p.name=row.name;

LOAD CSV WITH HEADERS FROM 'file:///products.csv' AS row
MERGE (p:Product {product_id: row.product_id}) SET p.name=row.name, p.category=row.category;

LOAD CSV WITH HEADERS FROM 'file:///brand_products.csv' AS row
MATCH (b:Brand {brand_id:row.brand_id}), (p:Product {product_id:row.product_id})
MERGE (b)-[r:OFFERS]->(p) SET r.list_price_idr=toInteger(row.list_price_idr);

LOAD CSV WITH HEADERS FROM 'file:///promotions.csv' AS row
MERGE (p:Promotion {promo_id: row.promo_id})
SET p.promo_type=row.promo_type, p.discount_pct=toInteger(row.discount_pct), p.channel=row.channel,
    p.start_date=date(row.start_date), p.end_date=date(row.end_date)
WITH p,row MATCH (b:Brand {brand_id:row.brand_id}) MERGE (b)-[:RUNS]->(p);

// ---------- 2. Outlets ----------
LOAD CSV WITH HEADERS FROM 'file:///outlets.csv' AS row
MERGE (o:Outlet {outlet_id: row.outlet_id})
SET o.name=row.name, o.ownership=row.ownership, o.status=row.status,
    o.opened_date=date(row.opened_date),
    o.closed_date=CASE WHEN row.closed_date='' THEN null ELSE date(row.closed_date) END,
    o.location=point({latitude:toFloat(row.latitude), longitude:toFloat(row.longitude)})
WITH o,row
MATCH (b:Brand {brand_id:row.brand_id}), (d:District {district_id:row.district_id}), (op:Operator {operator_id:row.operator_id})
MERGE (o)-[:OF_BRAND]->(b)
MERGE (o)-[:IN_DISTRICT]->(d)
MERGE (o)-[:OPERATED_BY]->(op)
MERGE (f:StoreFormat {name:row.store_format}) MERGE (o)-[:HAS_FORMAT]->(f)
MERGE (bt:BeanType {name:row.coffee_beans_type}) MERGE (o)-[:USES_BEANS]->(bt);

LOAD CSV WITH HEADERS FROM 'file:///outlet_amenity.csv' AS row
MATCH (o:Outlet {outlet_id:row.outlet_id})
MERGE (a:Amenity {name:row.amenity}) MERGE (o)-[:OFFERS_AMENITY]->(a);

LOAD CSV WITH HEADERS FROM 'file:///outlet_platform.csv' AS row
MATCH (o:Outlet {outlet_id:row.outlet_id}), (p:DeliveryPlatform {platform_id:row.platform_id})
MERGE (o)-[r:LISTED_ON]->(p)
SET r.commission_pct=toFloat(row.commission_pct), r.platform_rating=toFloat(row.platform_rating), r.avg_prep_min=toInteger(row.avg_prep_min);

// Competitor / cannibalisation proximity (stored once, query undirected)
LOAD CSV WITH HEADERS FROM 'file:///outlet_near_outlet.csv' AS row
WITH row WHERE row.same_brand='False'
MATCH (a:Outlet {outlet_id:row.outlet_a}), (b:Outlet {outlet_id:row.outlet_b})
MERGE (a)-[r:NEAR_COMPETITOR]-(b) SET r.distance_m=toInteger(row.distance_m);

LOAD CSV WITH HEADERS FROM 'file:///outlet_near_outlet.csv' AS row
WITH row WHERE row.same_brand='True'
MATCH (a:Outlet {outlet_id:row.outlet_a}), (b:Outlet {outlet_id:row.outlet_b})
MERGE (a)-[r:NEAR_SAME_BRAND]-(b) SET r.distance_m=toInteger(row.distance_m);

LOAD CSV WITH HEADERS FROM 'file:///poi_near_outlet.csv' AS row
MATCH (p:POI {poi_id:row.poi_id}), (o:Outlet {outlet_id:row.outlet_id})
MERGE (o)-[r:NEAR_POI]->(p) SET r.distance_m=toInteger(row.distance_m);

// ---------- 3. Snapshots (your ORIGINAL data rows, 1 row = 1 snapshot) ----------
LOAD CSV WITH HEADERS FROM 'file:///snapshots.csv' AS row
MERGE (s:Snapshot {snapshot_id: row.snapshot_id})
SET s.snapshot_date=date(row.snapshot_date),
    s.base_price_idr=toInteger(row.base_price_idr),
    s.discount_voucher_pct=toFloat(row.discount_voucher_pct),
    s.net_discounted_price_idr=toFloat(row.net_discounted_price_idr),
    s.daily_cups_sold=toInteger(row.daily_cups_sold),
    s.daily_revenue_estimate_idr=toFloat(row.daily_revenue_estimate_idr),
    s.competitor_density_500m=toInteger(row.competitor_density_500m),
    s.review_rating=toFloat(row.customer_review_rating),
    s.dwell_time_minutes=toInteger(row.dwell_time_minutes),
    s.price_competitiveness_ratio=toFloat(row.price_competitiveness_ratio),
    s.dwell_time_to_spend_ratio=toFloat(row.dwell_time_to_spend_ratio),
    s.cannibalization_risk_index=toFloat(row.cannibalization_risk_index),
    s.price_sensitivity_score=toFloat(row.customer_price_sensitivity_score),
    s.operating_margin_pct=toFloat(row.outlet_operating_margin_estimate_pct)
WITH s,row
MATCH (o:Outlet {outlet_id:row.outlet_id}) MERGE (o)-[:HAS_SNAPSHOT]->(s)
MERGE (sg:Segment {name:row.primary_customer_segment}) MERGE (s)-[:PRIMARY_SEGMENT]->(sg)
MERGE (om:OrderMethod {name:row.order_method}) MERGE (s)-[:DOMINANT_ORDER_METHOD]->(om)
MERGE (lt:LoyaltyTier {name:row.customer_brand_loyalty_tier}) MERGE (s)-[:DOMINANT_LOYALTY]->(lt)
MERGE (sd:SwitchDriver {name:row.primary_brand_switch_driver}) MERGE (s)-[:AT_RISK_OF]->(sd);

// Time chain per outlet
MATCH (o:Outlet)-[:HAS_SNAPSHOT]->(s:Snapshot)
WITH o, s ORDER BY s.snapshot_date
WITH o, collect(s) AS snaps WHERE size(snaps) > 1
UNWIND range(0, size(snaps)-2) AS i
WITH snaps[i] AS a, snaps[i+1] AS b
MERGE (a)-[:NEXT]->(b);

LOAD CSV WITH HEADERS FROM 'file:///snapshot_promotion.csv' AS row
MATCH (s:Snapshot {snapshot_id:row.snapshot_id}), (p:Promotion {promo_id:row.promo_id})
MERGE (s)-[:AFFECTED_BY]->(p);

// ---------- 4. Customers ----------
LOAD CSV WITH HEADERS FROM 'file:///customers.csv' AS row
MERGE (c:Customer {customer_id: row.customer_id})
SET c.age_band=row.age_band, c.app_user=(row.app_user='True'), c.joined_date=date(row.joined_date)
WITH c,row
MATCH (d:District {district_id:row.district_id}) MERGE (c)-[:LIVES_IN]->(d)
MERGE (sg:Segment {name:row.primary_segment}) MERGE (c)-[:IN_SEGMENT]->(sg)
MERGE (lt:LoyaltyTier {name:row.loyalty_tier}) MERGE (c)-[:HAS_LOYALTY]->(lt);

LOAD CSV WITH HEADERS FROM 'file:///customer_visits.csv' AS row
MATCH (c:Customer {customer_id:row.customer_id}), (o:Outlet {outlet_id:row.outlet_id})
MERGE (c)-[r:VISITED]->(o)
SET r.visits=toInteger(row.visits), r.total_spend_idr=toInteger(row.total_spend_idr),
    r.first_visit=date(row.first_visit), r.last_visit=date(row.last_visit);

LOAD CSV WITH HEADERS FROM 'file:///switch_events.csv' AS row
MATCH (c:Customer {customer_id:row.customer_id}),
      (f:Brand {brand_id:row.from_brand_id}), (t:Brand {brand_id:row.to_brand_id})
MERGE (e:SwitchEvent {event_id:row.event_id}) SET e.event_date=date(row.event_date)
MERGE (c)-[:HAD_SWITCH]->(e)
MERGE (e)-[:FROM_BRAND]->(f)
MERGE (e)-[:TO_BRAND]->(t)
MERGE (d:SwitchDriver {name:row.driver}) MERGE (e)-[:CAUSED_BY]->(d)
WITH e,row
OPTIONAL MATCH (fo:Outlet {outlet_id:row.from_outlet_id})
OPTIONAL MATCH (to_o:Outlet {outlet_id:row.to_outlet_id})
FOREACH (_ IN CASE WHEN fo IS NULL THEN [] ELSE [1] END | MERGE (e)-[:LEFT_OUTLET]->(fo))
FOREACH (_ IN CASE WHEN to_o IS NULL THEN [] ELSE [1] END | MERGE (e)-[:JOINED_OUTLET]->(to_o));

// ---------- 5. Sanity check ----------
MATCH (n) RETURN labels(n)[0] AS label, count(*) AS nodes ORDER BY nodes DESC;
