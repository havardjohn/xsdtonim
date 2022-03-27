## Adjusts an XSD-file so it's more standardized, and as such easier to parse.
## This is specifially intended for the `nim_xsdgen` program.
##
## # Adjustments
##
## * `complexType` and `simpleType` nodes under `element` nodes are moved to
##   the top-level of the XSD schema
## * `choice` nodes under `complexType` nodes that are not the sole node for
##   the `complexType` are moved into its own `complexType`

import std/[xmltree, options, strtabs]
import zero_functional
import helpers, builder

func splitChoices(xsd: XsdNode): Option[XsdNode] =
    xsd.expectKind xnkComplexType
    let seqNode = xsd.seqOfComplexType
    let subs = seqNode.subnodes
    if subs.len <= 1:
        return
    let choiceIdx = subs --> index(it.kind == xnkChoice)
    if choiceIdx == -1:
        return
    let choice = subs[choiceIdx]
    let arity = choice.elemArity
    let choiceName = xsd.name & "Choice"
    let elem = choiceName.newElement(choiceName)
    elem.attrs["flatten"] = "1" # To tell `xsdtonim` to `xmlFlatten` the element
    for elem in choice.XmlNode.items:
        elem.attrs["minOccurs"] = $arity.min
        elem.attrs["maxOccurs"] = $arity.max
    choice.attrs.del"minOccurs"
    choice.attrs.del"maxOccurs"
    let ty = choiceName.newComplexType(choice)
    seqNode.XmlNode.delete choiceIdx
    seqNode.XmlNode.insert(elem.XmlNode, choiceIdx)
    some(ty)

func splitTypeFromElement*(xsd: XsdNode): XsdNode =
    xsd.expectKind xnkElement
    if xsd.len == 0:
        return
    let
        elemName = xsd.name
        tyIdx = xsd.subnodes --> index(it.kind in {xnkSimpleType, xnkComplexType})
        ty = xsd[tyIdx]
    xsd.XmlNode.delete tyIdx
    xsd.setTy XsdType(isPrimitive: false, name: elemName)
    ty.setName elemName
    ty

func splitTypes*(xsd: XsdNode): seq[XsdNode] =
    case xsd.kind
    of xnkElement:
        let ty = splitTypeFromElement xsd
        if ty.XmlNode.isNil:
            @[]
        else:
            ty.splitTypes & ty
    of xnkComplexType:
        xsd.elemsOfComplexType --> map(it.splitTypes).flatten()
    else: @[]

func standardizeXsd*(xsd: seq[XsdNode]): seq[XsdNode] =
    ## Return a clone of the XSD schema that is "normalized".
    let splitTypes = xsd --> map(it.splitTypes).flatten()
    let newRet = splitTypes & xsd
    let splitUnions = newRet -->
        filter(it.kind == xnkComplexType).
        map(it.splitChoices).
        filter(it.isSome).
        map(it.unsafeGet)
    splitUnions & newRet
