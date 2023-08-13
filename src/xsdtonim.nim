import
    std/[
        options,
    ],

    xmlserde

type
    XsElement = object
        name {.xmlAttr.}: string
        minOccurs {.xmlAttr.}: Option[int]
        maxOccurs {.xmlAttr.}: Option[string]
        default {.xmlAttr.}: Option[string]
        annotation {.xmlName: "xs:annotation".}: Option[XsAnnotation]

        # Either...
        typ {.xmlName: "type", xmlAttr.}: Option[string]
        # OR ...
        simpleType {.xmlName: "xs:simpleType".}: Option[XsSimpleType]

    XsChoice = object
        element {.xmlName: "xs:element".}: seq[XsElement]
        minOccurs {.xmlAttr.}: Option[int]

    XsSequence = object
        element* {.xmlName: "xs:element".}: seq[XsElement]
        choice* {.xmlName: "xs:choice".}: seq[XsChoice]
        sequence* {.xmlName: "xs:sequence".}: seq[XsSequence]

    XsAttribute = object
        name {.xmlAttr.}: string
        typ {.xmlAttr, xmlName: "type".}: string
        use {.xmlAttr.}: string

    XsExtension = object
        base {.xmlAttr.}: string
        attribute {.xmlName: "xs:attribute".}: seq[XsAttribute]

    XsSimpleContent = object
        extension {.xmlName: "xs:extension".}: XsExtension

    XsComplexType = object
        name {.xmlAttr.}: string
        sequence {.xmlName: "xs:sequence".}: Option[XsSequence]
        simpleContent {.xmlName: "xs:simpleContent".}: Option[XsSimpleContent]
        annotation {.xmlName: "xs:annotation".}: Option[XsAnnotation]

    XsEnumeration = object
        value {.xmlAttr.}: string
        annotation {.xmlName: "xs:annotation".}: Option[XsAnnotation]

    XsStringValue = object
        value {.xmlAttr.}: string

    XsIntValue = object
        value {.xmlAttr.}: int

    XsRestriction = object
        base {.xmlAttr.}: string
        enumeration {.xmlName: "xs:enumeration".}: seq[XsEnumeration]
            # string simpleType
        pattern {.xmlName: "xs:pattern".}: Option[XsStringValue]
            # string simpleType

        fractionDigits {.xmlName: "xs:fractionDigits".}: Option[XsIntValue]
        totalDigits {.xmlName: "xs:totalDigits".}: Option[XsIntValue]
        minInclusive {.xmlName: "xs:minInclusive".}: Option[XsIntValue]
            # decimal simpleType

        minLength {.xmlName: "xs:minLength".}: Option[XsIntValue]
        maxLength {.xmlName: "xs:maxLength".}: Option[XsIntValue]
            # string simpleType

    XsDocumentation = object
        text {.xmlText.}: string

    XsAnnotation = object
        documentation {.xmlName: "xs:documentation".}: XsDocumentation

    XsSimpleType = object
        name {.xmlAttr.}: Option[string]
            # none when nested inside an element node
        restriction {.xmlName: "xs:restriction".}: XsRestriction
        annotation {.xmlName: "xs:annotation".}: Option[XsAnnotation]

    XsSchema = object
        element {.xmlName: "xs:element".}: seq[XsElement]
        complexType {.xmlName: "xs:complexType".}: seq[XsComplexType]
        simpleType {.xmlName: "xs:simpleType".}: seq[XsSimpleType]

import
    std/[
        macros,
        sequtils,
        strformat,
        strutils,
        json,
        jsonutils,
    ],

    results

# {{{1 helpers

iterator items[T](x: Option[T]): lent T =
    if x.isSome:
        yield x.unsafeGet

proc parseMaxOccurs(x: string): int =
    if x == "unbounded":
        int.high
    else:
        parseInt(x)

proc filterIdentChars(s: string): string =
    result = newStringOfCap(s.len)
    for c in s:
        if c in IdentChars:
            result.add c

proc toExportedIdent(s: string): NimNode =
    nnkPostfix.newTree(ident"*", s.filterIdentChars.ident)

proc toTypeName(s: string, extraPragmas: varargs[NimNode]): NimNode =
    let
        name = s.toExportedIdent
        pragma = nnkPragma.newTree(nnkExprColonExpr.newTree(ident"xmlName", s.newLit))
    for p in extraPragmas:
        pragma.add p
    nnkPragmaExpr.newTree(name, pragma)

proc newPragma(s: string): NimNode =
    nnkPragma.newTree(s.ident)

proc xsdToNimPrimitiveType(s: string): string =
    ## Takes an XSD primitive type, and converts it to a Nim type
    ##
    ## `xs:decimal` becomes `string` for the sake of keeping precision if
    ## `xs:decimal` is a fixed-precision type (like money types).
    case s
    of "xs:string", "xs:decimal", "xs:date", "xs:dateTime": "string"
    of "xs:boolean": "bool"
    else: s

macro addDiag(p) =
    let body = p.body
    p.body = quote do:
        try:
            `body`
        except CatchableError:
            let e = getCurrentException()
            echo "Failed to parse for x = " & x.toJson.pretty & "\n" & e.msg &
                "\n" & e.getStackTrace
    result = p

# {{{1 generation

proc genField(x: XsElement, isopt: bool): NimNode {.addDiag.} =
    let
        baseTyp = x.typ.get.filterIdentChars.ident
        minOccurs = x.minOccurs.get(1)
        maxOccurs = x.maxOccurs.map(parseMaxOccurs).get(1)
        name = x.name.toTypeName
    let typ =
        if minOccurs > 1 or maxOccurs > 1:
            nnkBracketExpr.newTree(ident"seq", baseTyp)
        elif isopt or (minOccurs == 0 and maxOccurs == 1):
            nnkBracketExpr.newTree(ident"Option", baseTyp)
        else:
            baseTyp
    result = newIdentDefs(name, typ)

proc genField(x: XsAttribute): NimNode =
    let
        name = x.name.toTypeName(ident"xmlAttr")
        baseTyp = x.typ.filterIdentChars.ident
        typ =
            if x.use == "required":
                baseTyp
            else:
                nnkBracketExpr.newTree(ident"Option", baseTyp)
    newIdentDefs(name, typ)

proc genType(x: XsComplexType): NimNode =
    let recl = nnkRecList.newTree
    for c in x.simpleContent:
        let fld = nnkPragmaExpr.newTree(toExportedIdent"text", newPragma"xmlText")
        recl.add newIdentDefs(fld, c.extension.base.ident)
        for a in c.extension.attribute:
            recl.add a.genField
    for s in x.sequence:
        for c in s.choice:
            for e in c.element:
                recl.add e.genField(true)
        for e in s.element:
            recl.add e.genField(false)
    let
        objty = nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), recl)
        name = x.name.toExportedIdent
    nnkTypeDef.newTree(name, newEmptyNode(), objty)

proc toIdent(x: XsEnumeration): NimNode =
    x.value.ident

proc genType(x: XsSimpleType): NimNode =
    let basename = x.name.get.toExportedIdent
    let (name, typ) =
        if x.restriction.enumeration.len > 0:
            let
                name = nnkPragmaExpr.newTree(basename, nnkPragma.newTree(ident"pure"))
                ids = x.restriction.enumeration.map(toIdent)
                en = nnkEnumTy.newTree(newEmptyNode())
            en.add ids
            (name, en)
        else:
            (basename, x.restriction.base.xsdToNimPrimitiveType.ident)
    nnkTypeDef.newTree(name, newEmptyNode(), typ)

proc genTypesFromStringAux*(s: string): NimNode =
    # NOTE: This doesn't support comments in the beginning of the file!
    let xsd = s.deserString[:XsSchema]("xs:schema").get
    let types = nnkTypeSection
        .newNimNode
        .add(xsd.complexType.map(genType))
        .add(xsd.simpleType.map(genType))
    result = quote do:
        import std/options, xmlserde
        `types`

macro xsdToNimStringify*(s: static string): static string =
    result = genTypesFromStringAux(s).repr.strip.newLit

when isMainModule:
    const
        xsdFile {.strdefine.}: string = ""

    static:
        if xsdFile != "":
            echo genTypesFromStringAux(xsdFile.slurp).repr

    if xsdFile == "":
        quit "Add `nim c` argument `-d:xsdFile=$PWD/$file` to " &
            "the `$file` you want to generate bindings for"
