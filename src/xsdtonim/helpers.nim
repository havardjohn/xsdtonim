## Helpers on `std/xmltree.XmlNode` for XSD files in particular.

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

# {{{ XmlNode extensions

func expectKind*(node: XmlNode, kind: XmlNodeKind) =
    doAssert node.kind == kind, &"Expected node to be of kind {$kind}, but got {$node.kind}"

func subnodes*(node: XmlNode): seq[XmlNode] =
    result = newSeq[XmlNode](node.len)
    for i in 0..<node.len:
        result[i] = node[i]

# }}}

type
    XsdNode* = distinct XmlNode

    XsdNodeKind* = enum
        xnkAnnotation = "xsd:annotation"
        xnkAttribute = "xsd:attribute"
        xnkChoice = "xsd:choice"
        xnkComplexType = "xsd:complexType"
        xnkDocumentation = "xsd:documentation"
        xnkElement = "xsd:element"
        xnkEnumeration = "xsd:enumeration"
        xnkExtension = "xsd:extension"
        xnkPattern = "xsd:pattern"
        xnkRestriction = "xsd:restriction"
        xnkSequence = "xsd:sequence"
        xnkSimpleContent = "xsd:simpleContent"
        xnkSimpleType = "xsd:simpleType"
        xnkMaxLength = "xsd:maxLength"
        xnkMinLength = "xsd:minLength"
        xnkMinInclusive = "xsd:minInclusive"
        xnkMinExclusive = "xsd:minExclusive"
        xnkMaxInclusive = "xsd:maxInclusive"
        xnkMaxExclusive = "xsd:maxExclusive"

    XsdPrimitiveType* = enum
        xptNone
        xptString = "xsd:string"
        xptBoolean = "xsd:boolean"
        xptDecimal = "xsd:decimal"
        xptInteger = "xsd:int"
        xptNatural = "xsd:positiveInteger"
        xptFloat = "xsd:float"
        xptDouble = "xsd:double"
        xptDuration = "xsd:duration"
        xptDateTime = "xsd:datetime"
        xptTime = "xsd:time"
        xptDate = "xsd:date"
        xptGYearMonth = "xsd:gyearmonth"
        xptGYear = "xsd:gyear"
        xptGMonthDay = "xsd:gmonthday"
        xptGDay = "xsd:gday"
        xptGMonth = "xsd:gmonth"
        xptHexBinary = "xsd:hexbinary"
        xptBase64Binary = "xsd:base64binary"
        xptUri = "xsd:uri"
        xptLong = "xsd:long"

    XsdType* = object
        ## The `type` attribute of `xsd:element` nodes
        case isPrimitive*: bool
        of true:
            primitive*: XsdPrimitiveType
        of false:
            name*: string

func asNimType*(primitive: XsdPrimitiveType): string =
    const xsdTypeToNim = [
        xptNone: "",
        xptString: "string",
        xptBoolean: "bool",
        xptDecimal: "float",
        xptInteger: "int",
        xptNatural: "Natural",
        xptFloat: "float",
        xptDouble: "float64",
        xptDuration: "Duration",
        xptDateTime: "DateTime",
        xptTime: "Time",
        xptDate: "DateTime",
        xptGYearMonth: "DateTime",
        xptGYear: "DateTime",
        xptGMonthDay: "DateTime",
        xptGDay: "DateTime",
        xptGMonth: "DateTime",
        xptHexBinary: "string",
        xptBase64Binary: "string",
        xptUri: "Uri",
        xptLong: "int64"
    ]
    xsdTypeToNim[primitive]

func `$`*(ty: XsdType): string =
    case ty.isPrimitive
    of true: $ty.primitive
    of false: ty.name

func len*(xsd: XsdNode): int {.borrow.}
func `[]`*(xsd: XsdNode, i: int): XsdNode {.borrow.}

func subnodes*(node: XsdNode): seq[XsdNode] =
    node.XmlNode.subnodes.mapIt(it.XsdNode)

func attrs*(node: XsdNode): XmlAttributes =
    ## Equivalent to `node.XmlNode.attrs`, except it never returns `nil`.
    if node.XmlNode.attrs.isNil:
        node.XmlNode.attrs = newStringTable(modeCaseSensitive)
    node.XmlNode.attrs

func rawKindToConventionalKind(s: string): string =
    ## Converts e.g. `xs:element` to `xsd:element`.
    let splits = s.split(':', maxSplit = 1)
    assert splits.len == 2
    &"xsd:{splits[1]}"

func kind*(node: XsdNode): XsdNodeKind =
    try:
        parseEnum[XsdNodeKind](node.XmlNode.tag.rawKindToConventionalKind)
    except:
        debugEcho $node.XmlNode
        raise

func expectKind*(node: XsdNode, kinds: set[XsdNodeKind]) =
    assert node.kind in kinds, &"Expected node to be of {$kinds}, but got {$node.kind}"

func expectKind*(node: XsdNode, kind: XsdNodeKind) = node.expectKind {kind}

func ty*(node: XsdNode): XsdType =
    node.expectKind xnkElement
    let strVal = node.attrs["type"]
    let val = parseEnum[XsdPrimitiveType](strVal, xptNone)
    if val == xptNone:
        let valNoNs = strVal.split(':')[^1]
        XsdType(isPrimitive: false, name: valNoNs)
    else:
        XsdType(isPrimitive: true, primitive: val)

func baseTy*(node: XsdNode): XsdPrimitiveType =
    node.expectKind xnkRestriction
    parseEnum[XsdPrimitiveType](node.attrs["base"])

func name*(node: XsdNode): string =
    node.expectKind {xnkSimpleType, xnkComplexType, xnkElement}
    try:
        node.attrs["name"]
    except:
        debugEcho $node.XmlNode
        raise

func enumValue*(node: XsdNode): string =
    node.expectKind xnkEnumeration
    node.attrs["value"]

func docs*(node: XsdNode): string =
    node.expectKind {xnkSimpleType, xnkComplexType, xnkElement, xnkEnumeration}
    let annoNode = node.subnodes -->
        find(it.kind == xnkAnnotation)
    if annoNode.isNone:
        return
    let docNode = annoNode.get.subnodes -->
        find(it.kind == xnkDocumentation)
    if docNode.isNone:
        return
    docNode.get.XmlNode.innerText.split(WhiteSpace) -->
        filter(it != "").
        reduce(it.accu & " " & it.elem)

func seqOfComplexType*(xsd: XsdNode): XsdNode =
    xsd.expectKind xnkComplexType
    xsd.subnodes --> find(it.kind == xnkSequence).get

func elemsOfComplexType*(xsd: XsdNode): seq[XsdNode] =
    ## Convenience for extracting the `sequence` list of `element` (and other
    ## special kinds of) nodes from a `complexType`
    xsd.seqOfComplexType.subnodes

# {{{ Arity

type
    XsdArity* = tuple[min, max: Natural]
        ## Arity of an XSD `element`

func arityOf(node: string): Natural =
    if node == "unbounded":
        Natural.high
    else:
        node.parseInt

func elemArity*(node: XsdNode): XsdArity =
    ## The minimum and maximum number of elements of this kind allowed
    node.expectKind {xnkElement, xnkChoice}
    let rawMin = node.attrs.getOrDefault("minOccurs", "1")
    let rawMax = node.attrs.getOrDefault("maxOccurs", "1")
    (arityOf rawMin, arityOf rawMax)

func isOptionElement*(arity: XsdArity): bool =
    arity.min == 0 and arity.max == 1

func isSeqElement*(arity: XsdArity): bool =
    arity.min != 1 or arity.max != 1

# }}}

func isEnumRestriction*(node: XsdNode): bool =
    node.expectKind xnkRestriction
    node.baseTy == xptString and node.subnodes.allIt(it.kind == xnkEnumeration)

func getRangeValue(subs: seq[XsdNode], kind: XsdNodeKind): Option[int] =
    assert kind in {xnkMinExclusive, xnkMinInclusive, xnkMaxExclusive, xnkMaxInclusive}
    let opt = subs --> find(it.kind == kind)
    opt.map(x => x.attrs["value"].parseInt)

func getRangeRestriction*(node: XsdNode): tuple[min, max: int] =
    node.expectKind xnkRestriction
    let subs = node.subnodes
    var min = subs.getRangeValue(xnkMinInclusive)
    if min.isNone:
        min = subs.getRangeValue(xnkMinExclusive).map(x => x.succ)
    var max = subs.getRangeValue(xnkMaxInclusive)
    if max.isNone:
        max = subs.getRangeValue(xnkMaxExclusive).map(x => x.pred)
    (min.get(int.low), max.get(int.high))

func isRangeRestriction*(node: XsdNode): bool =
    node.expectKind xnkRestriction
    node.baseTy == xptInteger and node.subnodes.anyIt(it.kind in
        {xnkMinInclusive, xnkMinExclusive, xnkMaxInclusive, xnkMaxExclusive})

func simpleParseXsd*(root: XmlNode): seq[XsdNode] =
    ## Takes a XSD document from the root (the root node expected to benamed `xsd:schema`), and
    ## outputs its child nodes.
    root.expectKind xnElement
    root.subnodes -->
        filter(it.kind == xnElement). # Filter away comments
        map(it.XsdNode)
