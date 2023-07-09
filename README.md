# xsdtonim

An in-complete generator of Nim structures from an XSD schema file. The
structures generated use the primitives from the Nim standard library as well
as `std/options.Option`.

This library works closely with
[xmlserde](https://github.com/havardjohn/xmlserde.nim) by adding its custom
pragmas to object fields. This is mostly to normalize XML names with Nim
identifiers and working with unions.

## How-to

Clone this repo, set `MYXSDFILE` variable to the XSD file you wish to generate
Nim bindings from, and run

```
nim c -d:xsdFile=$MYXSDFILE src/xsdtonim.nim > out.nim
```

Now the bindings are in the file `out.nim`.

## Inner workings

Note that the XSD file is first modified before generating structures. For
details, see `normalizer.nim`.
