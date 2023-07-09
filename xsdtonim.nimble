# Package

version       = "0.2.0"
author        = "Håvard Mjaavatten"
description   = "Generate Nim structures from XSD files"
license       = "MIT"
srcDir        = "src"


# Dependencies

# 1.4.0 first major version in which the `len` borrow for `XsdNode` of
# `XmlNode` in `helpers.nim` compiles.
requires "nim >= 1.4.0"
requires "xmlserde >= 0.1.3 & < 0.2"
