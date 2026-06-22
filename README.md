# sml-geo

[![CI](https://github.com/sjqtentacles/sml-geo/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-geo/actions/workflows/ci.yml)

GeoJSON (RFC 7946) typed geometry model for Standard ML: a full abstract
syntax tree mirroring the spec's geometry and feature hierarchy, a parser
that validates JSON values against the GeoJSON grammar, a canonical
serializer, and bounding-box computation.

Part of the `sjqtentacles` monorepo of SML libraries. It depends on
[`sml-json`](https://github.com/sjqtentacles/sml-json) (vendored, which in
turn vendors `sml-parsec`) for the JSON value tree and parser.

## Features

- **Full GeoJSON ADT** -- all seven geometry types (Point, MultiPoint,
  LineString, MultiLineString, Polygon, MultiPolygon, GeometryCollection),
  features with optional geometry and JSON properties, and feature
  collections.
- **Parser** -- `GeoJsonParser.fromJson : Json.json -> t result` validates
  `type` discriminants, coordinate array shapes, and required members,
  returning `Err msg` on any structural violation.
- **Serializer** -- `GeoJsonSerializer.toJson : t -> Json.json` produces a
  JSON value in canonical member order (`type` first, then `coordinates` /
  `geometries`, then `properties` / `features`).
- **Bounding box** -- `GeoJsonBbox.bbox : geometry -> real * real * real * real`
  computes `(minLon, minLat, maxLon, maxLat)`, the four-number form of
  RFC 7946 section 5. `GeometryCollection` boxes are the union of members.

## Status

Working and tested. The parser, serializer, and bbox cover all geometry
types, features, and feature collections, exercised by RFC 7946 examples.

## Portability

Pure Standard ML using only the Basis library (plus the vendored
`sml-json`) -- no FFI, no threads. Verified on **MLton** and **Poly/ML**,
with identical, deterministic output across both.

## Building and testing

```sh
make test        # build + run the suite under MLton (default)
make test-poly   # run the suite under Poly/ML
make all-tests   # run under both
make clean
```

## Usage

```sml
(* Parse a GeoJSON Point. *)
val json = Json.parseJson "{\"type\":\"Point\",\"coordinates\":[102.0,0.5]}"
val geo = case json of
    CharParsec.Ok v => (case GeoJsonParser.fromJson v of
                            GeoJsonParser.Ok g => g
                          | GeoJsonParser.Err e => raise Fail e)
  | CharParsec.Err e => raise Fail (CharParsec.errorToString e)
(* geo = Geometry (Point [102.0, 0.5]) *)

(* Serialize back to JSON. *)
val json' = GeoJsonSerializer.toJson geo
(* json' = JObj [("type", JStr "Point"), ("coordinates", JArr [...])] *)

(* Compute a bounding box. *)
val box = GeoJsonBbox.bbox (GeoJson.LineString [[0.0,0.0],[10.0,5.0],[3.0,8.0]])
(* box = (0.0, 0.0, 10.0, 8.0) *)
```

## API summary

| Function | Description |
| --- | --- |
| `GeoJson.geometry`, `GeoJson.feature`, `GeoJson.t` | The GeoJSON ADT. |
| `GeoJsonParser.fromJson : Json.json -> t result` | Parse a JSON value as GeoJSON. |
| `GeoJsonSerializer.toJson : t -> Json.json` | Serialize GeoJSON to a JSON value. |
| `GeoJsonBbox.bbox : geometry -> real * real * real * real` | Bounding box of a geometry. |

## Dependencies

- [`sml-json`](https://github.com/sjqtentacles/sml-json) (vendored, which
  vendors `sml-parsec`) -- JSON AST, parser, and serializer.

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-geo
smlpkg sync
```

Then reference the library basis from your own `.mlb`:

```
lib/github.com/sjqtentacles/sml-geo/sml-geo.mlb
```

For Poly/ML, `use` the sources listed in `sources.mlb` in order (the vendored
`sml-json` first, then `geo.sig` and `geo.sml`).

## License

MIT. See [LICENSE](LICENSE).
