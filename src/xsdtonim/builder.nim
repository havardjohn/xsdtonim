## Simple building of XSD-trees for testing/debugging purposes.

import std/[xmltree, strtabs, sequtils]
import zero_functional
import helpers

# {{{ Helpers for mutating `XsdNode` when building

func `$`*(x: XsdNode): string {.borrow.}

func `==`*(x, y: XsdNode): bool =
    $x == $y

func setName*(node: XsdNode, val: string) =
    node.expectKind {xnkSimpleType, xnkComplexType, xnkElement}
    node.attrs["name"] = val

func setTy*(node: XsdNode, val: XsdType) =
    node.expectKind xnkElement
    node.attrs["type"] = $val

# }}}

func newXmlAttrs*: XmlAttributes = newStringTable(modeCaseSensitive)
    ## Used to allow an attribute list to be empty and not nil

func newElement*(name: string, ty, minOccurs, maxOccurs = "",
                 subnodes: openArray[XsdNode] = [], attrs = newXmlAttrs()): XsdNode =
    attrs["name"] = name
    if ty != "": attrs["type"] = ty
    if minOccurs != "": attrs["minOccurs"] = minOccurs
    if maxOccurs != "": attrs["maxOccurs"] = maxOccurs
    newXmlTree($xnkElement, openArray[XmlNode](subnodes), attributes = attrs).XsdNode

func newChoice*(subnodes: openArray[XsdNode], minOccurs, maxOccurs: string): XsdNode =
    let attrs = newXmlAttrs()
    if minOccurs != "": attrs["minOccurs"] = minOccurs
    if maxOccurs != "": attrs["maxOccurs"] = maxOccurs
    newXmlTree($xnkChoice, openArray[XmlNode](subnodes), attributes = attrs).XsdNode

func newChoice*(subnodes: varargs[XsdNode]): XsdNode =
    newChoice(subnodes, "", "")

func newSequence*(elems: varargs[XsdNode]): XsdNode =
    newXmlTree($xnkSequence, varargs[XmlNode](elems)).XsdNode

func newDocs*(value: string): XsdNode =
    newXmlTree($xnkAnnotation, [newXmlTree($xnkDocumentation, [newEntity value])]).XsdNode

# {{{ Restrictions

func newRestriction*(base: XsdPrimitiveType, elems: varargs[XsdNode] = []): XsdNode =
    newXmlTree($xnkRestriction, varargs[XmlNode](elems),
               attributes = {"base": $base}.toXmlAttributes).XsdNode

func newEnum*(value: string): XsdNode =
    newXmlTree($xnkEnumeration, [], attributes = {"value": value}.toXmlAttributes).XsdNode

func newEnumRestriction*(variants: openArray[string]): XsdNode =
    let nodes = variants.mapIt(it.newEnum)
    newRestriction(xptString, nodes)

# }}}

func newComplexType*(name: string, elems: openArray[XsdNode], attrs: XmlAttributes): XsdNode =
    ## `elems` is a list of `xnkElement`s
    doAssert elems.allIt(it.kind in {xnkElement, xnkChoice})
    if name != "": attrs["name"] = name
    newXmlTree($xnkComplexType, [newSequence(elems).XmlNode], attributes = attrs).XsdNode

func newComplexType*(name: string, elems: varargs[XsdNode]): XsdNode =
    newComplexType(name, elems, newXmlAttrs())

func newSimpleType*(name: string, restriction: XsdNode): XsdNode =
    restriction.expectKind xnkRestriction
    var attrs = newXmlAttrs()
    if name != "": attrs["name"] = name
    newXmlTree($xnkSimpleType, [restriction.XmlNode], attributes = attrs).XsdNode
