(* Tests for sml-geo.

   Exercises the GeoJSON AST, parser, serializer, and bbox against RFC 7946
   examples: the section 1.5 Point, a Polygon with a hole, a FeatureCollection
   with mixed geometry types, a null-geometry Feature, bbox computation, and
   the invalid-type error case. *)

structure GeoTests =
struct
  open Harness
  open Json
  open GeoJson

  (* JSON equality (from sml-json tests, adapted): JInt exact, JReal within
     tolerance, JObj compared as ordered key/value lists. *)
  fun jsonEq (a, b) =
      case (a, b) of
          (JNull, JNull) => true
        | (JBool x, JBool y) => x = y
        | (JInt x, JInt y) => x = y
        | (JReal x, JReal y) => Real.abs (x - y) < 1E~9
        | (JStr x, JStr y) => x = y
        | (JArr xs, JArr ys) => listEq (xs, ys)
        | (JObj xs, JObj ys) => memEq (xs, ys)
        | _ => false
  and listEq (xs, ys) =
      length xs = length ys andalso ListPair.all jsonEq (xs, ys)
  and memEq (xs, ys) =
      length xs = length ys andalso
      ListPair.all (fn ((k1, v1), (k2, v2)) => k1 = k2 andalso jsonEq (v1, v2))
                   (xs, ys)

  (* Parse a JSON string, raising on error (for test convenience). *)
  fun parseJsonStr s =
      case Json.parseJson s of
          CharParsec.Ok v => v
        | CharParsec.Err e =>
            raise Fail ("JSON parse error: " ^ CharParsec.errorToString e)

  (* Parse a GeoJSON string. *)
  fun parseGeo s = GeoJson.fromJson (parseJsonStr s)

  (* Check that a GeoJSON parse succeeded and the result satisfies a predicate. *)
  fun checkOk (name, json, pred) =
      (case parseGeo json of
           Ok v => check name (pred v)
         | Err e => check (name ^ " (should parse)") false)

  fun checkErr (name, json) =
      (case parseGeo json of
           Ok _ => check (name ^ " (should fail)") false
         | Err _ => check name true)

  fun run () =
    let
      val () = section "RFC 7946 section 1.5 Point"

      (* RFC 7946 section 1.5 example: Point with coordinates [102.0, 0.5]. *)
      val pointJson = "{\"type\":\"Point\",\"coordinates\":[102.0,0.5]}"
      val () = checkOk ("Point parses", pointJson,
             fn Geometry (Point [lon, lat]) =>
                  Real.== (lon, 102.0) andalso Real.== (lat, 0.5)
              | _ => false)

      (* Round-trip: parse -> serialize -> parse should give the same value. *)
      val pointVal = (case parseGeo pointJson of Ok v => v | _ => Geometry (Point []))
      val () = check "Point round-trip"
                   (jsonEq (GeoJson.toJson pointVal, parseJsonStr pointJson))

      (* Serialize a Point built directly. *)
      val () = check "Point serialize"
                   (jsonEq (GeoJson.toJson (Geometry (Point [102.0, 0.5])),
                            parseJsonStr pointJson))

      val () = section "Polygon with hole"

      (* RFC 7946 section 3.1.6 example: a polygon with an exterior ring and an
         interior ring (hole). Coordinates:
         exterior: [[100,0],[101,0],[101,1],[100,1],[100,0]]
         hole:     [[100.2,0.2],[100.8,0.2],[100.8,0.8],[100.2,0.8],[100.2,0.2]] *)
      val polygonJson =
          "{\"type\":\"Polygon\",\"coordinates\":[" ^
          "[[100.0,0.0],[101.0,0.0],[101.0,1.0],[100.0,1.0],[100.0,0.0]]," ^
          "[[100.2,0.2],[100.8,0.2],[100.8,0.8],[100.2,0.8],[100.2,0.2]]" ^
          "]}"
      val () = checkOk ("Polygon with hole parses", polygonJson,
             fn Geometry (Polygon [exterior, hole]) =>
                  length exterior = 5 andalso length hole = 5
              | _ => false)

      (* Round-trip the polygon. *)
      val polygonVal = (case parseGeo polygonJson of Ok v => v | _ => Geometry (Point []))
      val () = check "Polygon round-trip"
                   (jsonEq (GeoJson.toJson polygonVal, parseJsonStr polygonJson))

      val () = section "FeatureCollection"

      (* A FeatureCollection with two features: a Point and a LineString. *)
      val fcJson =
          "{\"type\":\"FeatureCollection\",\"features\":[" ^
          "{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[1.0,2.0]},\"properties\":{\"name\":\"a\"}}," ^
          "{\"type\":\"Feature\",\"geometry\":{\"type\":\"LineString\",\"coordinates\":[[0.0,0.0],[1.0,1.0]]},\"properties\":{}}" ^
          "]}"
      val () = checkOk ("FeatureCollection parses", fcJson,
             fn FeatureCollection fs => length fs = 2
              | _ => false)
      (* Round-trip. *)
      val fcVal = (case parseGeo fcJson of Ok v => v | _ => Geometry (Point []))
      val () = check "FeatureCollection round-trip"
                   (jsonEq (GeoJson.toJson fcVal, parseJsonStr fcJson))

      (* Mixed geometry types in one collection. *)
      val () = checkOk ("FeatureCollection has mixed geometries", fcJson,
             fn FeatureCollection fs =>
                  let
                    val geoms = List.map
                      (fn Feature {geometry, ...} =>
                          case geometry of
                              SOME g => g
                            | NONE => Point [])  (* sentinel *)
                      fs
                  in
                    length geoms = 2
                    andalso List.all (fn Point _ => true | LineString _ => true
                                       | _ => false) geoms
                  end
              | _ => false)

      val () = section "null geometry Feature"

      (* A Feature with null geometry. *)
      val nullGeoJson =
          "{\"type\":\"Feature\",\"geometry\":null,\"properties\":{}}"
      val () = checkOk ("null geometry Feature parses", nullGeoJson,
             fn Feat (Feature {geometry = NONE, ...}) => true
              | _ => false)
      (* Round-trip. *)
      val nullGeoVal = (case parseGeo nullGeoJson of Ok v => v | _ => Geometry (Point []))
      val () = check "null geometry Feature round-trip"
                   (jsonEq (GeoJson.toJson nullGeoVal, parseJsonStr nullGeoJson))

      val () = section "bbox"

      (* Compare two (minLon, minLat, maxLon, maxLat) boxes with real equality. *)
      fun boxEq ((a1, a2, a3, a4), (b1, b2, b3, b4)) =
          Real.== (a1, b1) andalso Real.== (a2, b2)
          andalso Real.== (a3, b3) andalso Real.== (a4, b4)

      (* bbox of a Point is the point itself. *)
      val () = check "bbox Point"
                   (boxEq (GeoJson.bbox (Point [1.0, 2.0]), (1.0, 2.0, 1.0, 2.0)))

      (* bbox of a LineString: min/max of the vertices. *)
      val ls = LineString [[0.0, 0.0], [10.0, 5.0], [3.0, 8.0]]
      val () = check "bbox LineString"
                   (boxEq (GeoJson.bbox ls, (0.0, 0.0, 10.0, 8.0)))

      (* bbox of the Polygon with hole: exterior ring spans [100,0]-[101,1]. *)
      val polyGeom = case parseGeo polygonJson of
          Ok (Geometry g) => g
        | _ => Point []   (* sentinel; the check below will fail *)
      val () = check "bbox Polygon"
                   (boxEq (GeoJson.bbox polyGeom, (100.0, 0.0, 101.0, 1.0)))

      (* bbox of a GeometryCollection is the union of member boxes. *)
      val gc = GeometryCollection
                 [Point [0.0, 0.0], Point [5.0, 3.0], LineString [[1.0, 1.0],[2.0, 2.0]]]
      val () = check "bbox GeometryCollection"
                   (boxEq (GeoJson.bbox gc, (0.0, 0.0, 5.0, 3.0)))

      val () = section "invalid type error"

      (* An invalid geometry type string -> Err. *)
      val badTypeJson = "{\"type\":\"NotAType\",\"coordinates\":[]}"
      val () = checkErr ("invalid type fails", badTypeJson)

      (* Missing type entirely -> Err. *)
      val noTypeJson = "{\"coordinates\":[1.0,2.0]}"
      val () = checkErr ("missing type fails", noTypeJson)

      (* Top-level array (not an object) -> Err. *)
      val arrJson = "[1,2,3]"
      val () = checkErr ("top-level array fails", arrJson)

      val () = section "large integers (arbitrary precision)"

      (* Regression for the sml-json AST change: `JInt` now carries an
         arbitrary-precision `IntInf.int`. Integer JSON numbers flowing through
         geo's public parser must no longer overflow a fixed-width `int`
         (32-bit on MLton, 63-bit on Poly/ML). *)

      (* (1) Integer coordinates past 2^31 reach `parseNum`, which widens with
         `Real.fromLargeInt`. Under the old `Real.fromInt` this raised Overflow
         on MLton's 32-bit `int`. 3000000000 = 3e9 > 2^31, and its exact `real`
         value is representable, so we can assert it round-trips through a
         double. *)
      val bigCoordJson =
          "{\"type\":\"Point\",\"coordinates\":[3000000000,0]}"
      val () = checkOk ("large integer coordinate parses", bigCoordJson,
             fn Geometry (Point [lon, lat]) =>
                  Real.== (lon, 3000000000.0) andalso Real.== (lat, 0.0)
              | _ => false)

      (* (2) A large integer feature `id` reaches the `IntInf.toString` arm.
         9999999999999999999 > 2^63, so it exceeds BOTH MLton's and Poly/ML's
         fixed-width `int`; only arbitrary precision preserves it losslessly. *)
      val bigIdJson =
          "{\"type\":\"Feature\",\"id\":9999999999999999999," ^
          "\"geometry\":null,\"properties\":{}}"
      val () = checkOk ("large integer id stringifies losslessly", bigIdJson,
             fn Feat (Feature {id = SOME s, ...}) =>
                  s = "9999999999999999999"
              | _ => false)
    in
      ()
    end
end
