# Campus data setup

No actual campus coordinates, footprints, routes, floor counts or floor plans are bundled. The visual screenshot mentioned in the brief was not attached. The official tour landing page is linked without scraping its content.

1. Obtain university permission and survey building entrances, walking intersections, accessibility and boundaries. Record source, date, verifier and uncertainty in each record.
2. Configure Firebase and assign an admin custom claim to the authorized operator using the Admin SDK in a trusted environment.
3. Sign in → Settings → Campus data administration. Add stable building IDs, descriptions, categories and independently verified coordinates. Save draft records with verified=false; publish only after review.
4. Use the advanced record editor to load/edit the collections in DATABASE_SCHEMA.md. A verified building may be published; a provisional published building remains labelled and is excluded from map markers.
5. Add verified floors only when the floor exists. Set `planUrl` on each floor to an authorized HTTPS image; store attribution/permission in the corresponding floorPlans record. Images must be hosted by an authorized operator; binary file upload UI is not included.
6. Add rooms and normalized plan coordinates, floor connections and surveyed directed edges in `indoorPaths/{buildingId}`. Link rooms to nodeId. Routes are not inferred from the plan image.
7. Add verified `qrCheckpoints/{id}` linked to existing floors. Encode `srm-campus://checkpoint/{id}` in printed QR signs. Do not use `srm-demo` codes on real signs.
8. Add `campusPaths/walking` using x=latitude/y=longitude. An entrance destination node's ID or label must match the building ID. Include surveyed meters, accessible flags and clear directions. Users manually confirm starting graph checkpoints.
9. Field-test each route and checkpoint with campus staff, including accessible paths and closed entrances.

Production polygon boundary/building confirmation UI remains pending. The tested boundary classifier accepts local metric coordinates; convert geospatial polygons to a local metric frame before applying accuracy distances. Do not feed degree coordinates into a meter-based uncertainty check.
