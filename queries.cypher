// 1. Brand-to-brand switching flows (who steals from whom, and why)
MATCH (f:Brand)<-[:FROM_BRAND]-(e:SwitchEvent)-[:TO_BRAND]->(t:Brand), (e)-[:CAUSED_BY]->(d:SwitchDriver)
RETURN f.name AS lost_from, t.name AS gained_by, d.name AS driver, count(*) AS switches
ORDER BY switches DESC LIMIT 20;

// 2. Cannibalisation: same-brand outlets within 500 m, ranked by city
MATCH (a:Outlet)-[r:NEAR_SAME_BRAND]-(b:Outlet)
WHERE id(a) < id(b)
MATCH (a)-[:IN_DISTRICT]->(:District)-[:IN_CITY]->(c:City)
RETURN c.name AS city, a.name AS outlet_a, b.name AS outlet_b, r.distance_m AS metres
ORDER BY metres LIMIT 20;

// 3. Which POI types sit next to the highest-margin outlets?
MATCH (o:Outlet)-[:NEAR_POI]->(p:POI), (o)-[:HAS_SNAPSHOT]->(s:Snapshot)
RETURN p.poi_type AS poi_type, count(DISTINCT o) AS outlets, round(avg(s.operating_margin_pct),1) AS avg_margin_pct
ORDER BY avg_margin_pct DESC;

// 4. Franchise operators with the biggest footprint across brands/cities
MATCH (op:Operator {operator_type:'franchisee'})<-[:OPERATED_BY]-(o:Outlet)-[:OF_BRAND]->(b:Brand)
RETURN op.name, count(o) AS outlets, collect(DISTINCT b.name) AS brands
ORDER BY outlets DESC LIMIT 10;

// 5. Competitive pressure: outlets with many rivals within 500 m AND thin margins
MATCH (o:Outlet)-[:NEAR_COMPETITOR]-(rival:Outlet)
WITH o, count(DISTINCT rival) AS rivals
MATCH (o)-[:HAS_SNAPSHOT]->(s:Snapshot)
WITH o, rivals, avg(s.operating_margin_pct) AS margin
WHERE rivals >= 8 AND margin < 22
RETURN o.name, rivals, round(margin,1) AS margin ORDER BY rivals DESC LIMIT 20;

// 6. Customer journey: customers who left a brand because of WiFi/seating, and where they went
MATCH (c:Customer)-[:HAD_SWITCH]->(e:SwitchEvent)-[:CAUSED_BY]->(:SwitchDriver {name:'Lack-Of-Seating-WiFi'}),
      (e)-[:FROM_BRAND]->(f:Brand), (e)-[:TO_BRAND]->(t:Brand)
RETURN f.name, t.name, count(*) AS n ORDER BY n DESC;

// 7. Promo effectiveness: discount depth vs cups sold vs margin
MATCH (s:Snapshot)-[:AFFECTED_BY]->(p:Promotion)
RETURN p.promo_type, round(avg(p.discount_pct),1) AS avg_discount,
       round(avg(s.daily_cups_sold)) AS avg_cups, round(avg(s.operating_margin_pct),1) AS avg_margin
ORDER BY avg_margin DESC;

// 8. Outlet time series (trend of an outlet's snapshots)
MATCH (o:Outlet)-[:HAS_SNAPSHOT]->(s:Snapshot)
WITH o, count(s) AS n ORDER BY n DESC LIMIT 1
MATCH p=(o)-[:HAS_SNAPSHOT]->(:Snapshot)-[:NEXT*]->(:Snapshot) RETURN p LIMIT 1;
