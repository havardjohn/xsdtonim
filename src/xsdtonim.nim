## Generate Nim structures according to a `.xsd` file. The output is a string.

# FAQ: Why not generate Nim structures through a macro? Cannot do so because
# Nim doesn't allow `ref` types for compile-time execution, and `XmlNode` is a
# `ref` type. The low-level XML parser `std/parsexml` uses streams, which are
# `ref` types as well.

import std/[
    options,
    sequtils,
    strformat,
    strtabs,
    strutils,
    sugar,
    xmltree,
]
import zero_functional
import xsdtonim/[helpers, normalizer]

# {{{1 Helpers

func withPrefix(s, prefix: string): string =
    ## Prepends `s` with `prefix` if `s` is not empty
    if s != "":
        prefix & s
    else:
        ""

func pragmasToStr(pragmas: openArray[string]): string =
    if pragmas.len > 0:
        "{.$#.}" % [pragmas.join(", ")]
    else:
        ""

func normalizeCustomTypeName(ty: string): string =
    ty.capitalizeAscii

func normalizeTypeNameOf(ty: XsdType): string =
    if ty.isPrimitive:
        ty.primitive.asNimType
    else:
        ty.name.normalizeCustomTypeName

func wrapTypeOfElement(tyName: string, arity: XsdArity): string =
    let format = if arity.isOptionElement:
        "Option[$#]"
    elif arity.isSeqElement:
        &"seq[$#]"
    else:
        "$#"
    format % [tyName]

# {{{1 Enum gen

func toEnumPrefix*(name: string): string =
    ## Tries to find the text to prefix each enum variant by inspecting the
    ## type name (`name`).
    let chars = name.toOpenArray(0, name.len - 1).toSeq
    chars -->
        filter(it in {'A'..'Z'}).
        map(it.toLowerAscii).
        fold(newString(0), a & it)

func formatEnumVariant(name, prefix: string): string =
    let ident = prefix & name.nimIdentNormalize
    &"{ident} = \"{name}\""

func genEnumVariant(xsd: XsdNode, prefix: string): string =
    xsd.expectKind xnkEnumeration
    let variant = xsd.enumValue.formatEnumVariant(prefix)
    let docs = xsd.docs.withPrefix(" ## ")
    variant & docs

# {{{1 Object gen

func genObjFieldDocs(xsd: XsdNode, arity: XsdArity): string =
    let baseDocs =
        if arity.isSeqElement and not arity.isOptionElement:
            &"Length is {arity.min}..{arity.max}."
        else:
            ""
    let docs = baseDocs & xsd.docs.withPrefix(" ")
    docs.withPrefix(" ## ")

func genObjField(xsd: XsdNode): string =
    xsd.expectKind xnkElement
    let
        xmlName = xsd.name
        name = block:
            var name = xmlName.normalizeCustomTypeName
            name[0] = name[0].toLowerAscii
            name
        tyName = xsd.ty.normalizeTypeNameOf
        arity = xsd.elemArity
        wrapper = tyName.wrapTypeOfElement(arity)
        docs = xsd.genObjFieldDocs(arity)
    var pragmas = @[&"xmlName: \"{xmlName}\""]
    if xsd.attrs.contains"flatten":
        pragmas.add "xmlFlatten"
    &"{name}* {pragmas.pragmasToStr}: {wrapper}{docs}"

func formatObjectVariant(idx: int, field: string): string =
    &"of {idx}: {field}"

func genObjectUnion(xsd: XsdNode): string =
    xsd.expectKind xnkChoice
    let variants = xsd.subnodes -->
        enumerate().
        map(formatObjectVariant(it.idx, it.elem.genObjField).indent(2)).
        reduce(it.accu & "\n" & it.elem)
    "case choice* {.xmlSkip.}: byte\n" & variants & "\n  else: discard"

# {{{1 Top-level gen

# TODO: Handle xsd:pattern, xsd:minLength, xsd:maxLength
func genSimpleType*(xsd: XsdNode): string =
    ## Generate enum from simpleType/restriction on xsd:string. Input is the
    ## `xsd:simpleType` node.
    func fmtDocs(docs: string): string = docs.withPrefix "\n  ## "
    xsd.expectKind xnkSimpleType
    let
        name = xsd.name.normalizeCustomTypeName
        restrictNode = (xsd.subnodes --> find(it.kind == xnkRestriction)).get
        baseDocs = xsd.docs
        impl =
            if restrictNode.isEnumRestriction:
                let prefix = name.toEnumPrefix
                let enumValues = restrictNode.subnodes -->
                    map(it.genEnumVariant(prefix).indent(2)).
                    reduce(it.accu & "\n" & it.elem)
                &"enum{baseDocs.fmtDocs}\n{enumValues}"
            else:
                let nimType = restrictNode.baseTy.asNimType
                let docs =
                    if restrictNode.isRangeRestriction:
                        let (min, max) = restrictNode.getRangeRestriction
                        baseDocs & &". Number may be between {min} and {max}."
                    else:
                        baseDocs
                &"{nimType}{docs.fmtDocs}"
    &"{name}* = {impl}"

func genComplexType*(xsd: XsdNode): string =
    ## Generates the type implementation for the "complexType" in `xsd`.
    doAssert xsd.kind == xnkComplexType
    let name = xsd.name.normalizeCustomTypeName
    let seqSubs = xsd.elemsOfComplexType
    assert seqSubs.countIt(it.kind == xnkChoice) <= 1, "Max 1 union (choice) in complex type"
    let fields = seqSubs -->
        filter(it.kind == xnkElement).
        map(it.genObjField.indent(2)).
        reduce(it.accu & "\n" & it.elem)
    let union = (seqSubs -->
        find(it.kind == xnkChoice)).
        map(x => x.genObjectUnion.indent(2)).
        get("")
    let recList = [fields, union] -->
        filter(it != "").
        reduce(it[0] & '\n' & it[1])
    &"{name}* = object\n" & recList

func parseXsdToNim*(xml: XmlNode): string =
    let xsd = xml.simpleParseXsd.standardizeXsd
    doAssert xsd.allIt(it.kind in {xnkSimpleType, xnkComplexType, xnkElement})
    let simples = xsd -->
        filter(it.kind == xnkSimpleType).
        map(it.genSimpleType.indent(2)).
        reduce(it.accu & "\n" & it.elem)
    let complex = xsd -->
        filter(it.kind == xnkComplexType).
        map(it.genComplexType.indent(2)).
        reduce(it.accu & "\n" & it.elem)
    &"""
import std/[options, times]
import xmlserde

type
{simples}
{complex}
"""

when isMainModule:
    import xmlparser
    proc main(filename: string) =
        let xml = loadXml(filename)
        echo parseXsdToNim xml

    import cligen
    dispatch main
