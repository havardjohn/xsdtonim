# xsdtonim

An in-complete generator of Nim structures from an XSD schema file. The
structures generated use the primitives from the Nim standard library as well
as `std/times.DateTime` and `std/options.Option`.

This library works closely with
[xmlserde](https://github.com/havardjohn/xmlserde.nim) by adding its custom
pragmas to object fields. This is mostly to normalize XML names with Nim
identifiers and working with unions.

## Inner workings

Note that the XSD file is first modified before generating structures. For
details, see `normalizer.nim`.
