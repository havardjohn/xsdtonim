import std/[unittest, strutils]
import xsdtonim, xsdtonim/[helpers, builder]

suite "tests":
    test "Object generation":
        let xsd = "someStruct".newComplexType(
            "hasSomething".newElement(ty = $xptBoolean),
            "AnInt".newElement(ty = $xptInteger, minOccurs = "0", maxOccurs = "4"),
        )
        check xsd.genComplexType == """
SomeStruct* = object
  hasSomething* {.xmlName: "hasSomething".}: bool
  anInt* {.xmlName: "AnInt".}: seq[int] ## Length is 0..4."""

    test "Enum generation":
        let xsd = "sortByType".newSimpleType(
            newEnumRestriction(["NAME", "PHONE", "EMAIL", "STATUS"]))
        check xsd.genSimpleType == """
SortByType* = enum
  sbtName = "NAME"
  sbtPhone = "PHONE"
  sbtEmail = "EMAIL"
  sbtStatus = "STATUS" """.strip

    test "Union generation":
        let xsd = "aChoiceType".newComplexType(
            newChoice("x".newElement($xptInteger), "y".newElement($xptString)))
        check xsd.genComplexType == """
AChoiceType* = object
  case choice* {.xmlSkip.}: byte
    of 0: x* {.xmlName: "x".}: int
    of 1: y* {.xmlName: "y".}: string
    else: discard
""".strip

    test "Enum prefix":
        check "SomeTest".toEnumPrefix == "st"
        check "AnotherKindOfTest".toEnumPrefix == "akot"
