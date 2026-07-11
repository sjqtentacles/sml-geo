(* demo.sml - typed GeoJSON geometries, serialize/parse round trip via the
   vendored sml-json, and bounding-box computation. Deterministic: identical
   output on every run and both compilers. *)

structure Geo = GeoJson

fun fmtR n r =
  let val r = if Real.== (r, 0.0) then 0.0 else r
  in Real.fmt (StringCvt.FIX (SOME n)) r end

fun bboxToString (minLon, minLat, maxLon, maxLat) =
  "[" ^ fmtR 4 minLon ^ ", " ^ fmtR 4 minLat ^ ", "
  ^ fmtR 4 maxLon ^ ", " ^ fmtR 4 maxLat ^ "]"

val () = print "GeoJSON demo\n"

val sf = Geo.Point [~122.4194, 37.7749]
val triangle = Geo.Polygon [[[0.0, 0.0], [4.0, 0.0], [4.0, 4.0], [0.0, 0.0]]]

val pointJson = Geo.toJson (Geo.Geometry sf)
val () = print ("serialized point       = " ^ JsonPretty.toString pointJson ^ "\n")

val () =
  case Geo.fromJson pointJson of
      Geo.Ok (Geo.Geometry (Geo.Point [lon, lat])) =>
        print ("round-trip point       = lon " ^ fmtR 4 lon ^ ", lat " ^ fmtR 4 lat ^ "\n")
    | Geo.Ok _ => print "round-trip point       = unexpected shape\n"
    | Geo.Err msg => print ("round-trip point       = parse error: " ^ msg ^ "\n")

val () = print ("triangle bbox           = " ^ bboxToString (Geo.bbox triangle) ^ "\n")

val collection = Geo.GeometryCollection [sf, triangle]
val () = print ("collection bbox         = " ^ bboxToString (Geo.bbox collection) ^ "\n")

val feature =
  Geo.Feature { geometry = SOME sf
              , properties = Json.JObj [("name", Json.JStr "San Francisco")]
              , id = SOME "city-1" }
val featureJson = Geo.toJson (Geo.Feat feature)
val () = print ("serialized feature      = " ^ JsonPretty.toString featureJson ^ "\n")

val () =
  case Geo.fromJson featureJson of
      Geo.Ok (Geo.Feat (Geo.Feature { id, ... })) =>
        print ("round-trip feature id   = " ^ (case id of SOME s => s | NONE => "none") ^ "\n")
    | Geo.Ok _ => print "round-trip feature id   = unexpected shape\n"
    | Geo.Err msg => print ("round-trip feature id   = parse error: " ^ msg ^ "\n")

(* malformed input: coordinates member is not an array of numbers *)
val bad = Json.JObj [("type", Json.JStr "Point"), ("coordinates", Json.JStr "nope")]
val () =
  case Geo.fromJson bad of
      Geo.Ok _ => print "bad point               = unexpectedly parsed\n"
    | Geo.Err msg => print ("bad point               = Err \"" ^ msg ^ "\"\n")
