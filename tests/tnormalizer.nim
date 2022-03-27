import std/[unittest, xmltree]
import xsdtonim/[normalizer, builder, helpers]

suite "Normalizer":
    test "Types inside elements are moved out":
        let xsd = @["anElem".newElement(subnodes = [
                "".newSimpleType(xptInteger.newRestriction([]))
            ])]
        check xsd.standardizeXsd == @[
            "anElem".newSimpleType(xptInteger.newRestriction([])),
            "anElem".newElement(ty = "anElem"),
        ]

    test "Element types are split correctly":
        let xsd = "x".newElement(subnodes = [
            "".newSimpleType(xptString.newRestriction([]))
            ])
        check xsd.splitTypeFromElement == "x".newSimpleType(xptString.newRestriction([]))
        check xsd == "x".newElement(ty = "x")

    test "Types inside elements inside complex types are moved out":
        let xsd = "x".newComplexType("y".newElement(subnodes = [
            "".newSimpleType(xptString.newRestriction([]))
        ]))
        check xsd.splitTypes == @[
            "y".newSimpleType(xptString.newRestriction([])),
        ]
        check xsd == "x".newComplexType("y".newElement(ty = "y"))

    test "Split union elements into their own type":
        let someElem = "y".newElement($xptString)
        let xsd = "x".newComplexType(someElem, newChoice(
            "a".newElement($xptString),
            "b".newElement($xptInteger)))
        check @[xsd].standardizeXsd == @[
            "xChoice".newComplexType(newChoice(
                "a".newElement($xptString, "1", "1"),
                "b".newElement($xptInteger, "1", "1"))),
            "x".newComplexType(someElem,
                "xChoice".newElement("xChoice",
                                     attrs = toXmlAttributes {"flatten": "1"}))]

    test "Don't split union elements if they are alone":
        let xsd = "x".newComplexType(newChoice(
            "a".newElement($xptString),
            "b".newElement($xptInteger)))
        check @[xsd].standardizeXsd == @[
            "x".newComplexType(newChoice(
                "a".newElement($xptString),
                "b".newElement($xptInteger)))]

    # "Correctly" means that the optionality of the choice is given to the
    # union elements instead of the union object itself. This is required for
    # the `xmlFlatten` attribute to work.
    test "Split optional union element into their own type correctly":
        let someElem = "y".newElement($xptString)
        let xsd = "x".newComplexType(someElem, newChoice([
            "a".newElement($xptString),
            "b".newElement($xptInteger)], "0", "1"))
        check @[xsd].standardizeXsd == @[
            "xChoice".newComplexType(newChoice(
                "a".newElement($xptString, "0", "1"),
                "b".newElement($xptInteger, "0", "1"))),
            "x".newComplexType(someElem,
                "xChoice".newElement("xChoice",
                                     attrs = toXmlAttributes {"flatten": "1"}))]
