# Package

version       = "0.1.0"
author        = "Håvard Mjaavatten"
description   = "Generate Nim structures from XSD files"
license       = "MIT"
srcDir        = "src"
bin           = @["xsdtonim"]


# Dependencies

# 1.4.0 first major version in which the `len` borrow for `XsdNode` of
# `XmlNode` in `helpers.nim` compiles.
requires "nim >= 1.4.0"
requires "zero_functional >= 1.2.1"
requires "cligen >= 1.5.0"
