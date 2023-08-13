import std/[unittest, strutils]
import xsdtonim

proc `==`(x, y: string): bool =
    system.`==`(x.strip, y.strip)

suite "tests":
    test "String simple type":
        const xsd = """
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xs:schema>
  <xs:simpleType name="MyString">
    <xs:restriction base="xs:string"/>
  </xs:simpleType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """import
  std / options, xmlserde

type
  MyString* = string"""

    test "Bool simple type":
        const xsd = """
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xs:schema>
  <xs:simpleType name="MyBool">
    <xs:restriction base="xs:boolean"/>
  </xs:simpleType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """import
  std / options, xmlserde

type
  MyBool* = bool"""

    test "Decimal simple type":
        const xsd = """
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xs:schema>
  <xs:simpleType name="MyDecimal">
    <xs:restriction base="xs:decimal"/>
  </xs:simpleType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """import
  std / options, xmlserde

type
  MyDecimal* = string"""

    test "Object generation":
        const xsd = """
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xs:schema>
  <xs:simpleType name="MyString">
    <xs:restriction base="xs:string"/>
  </xs:simpleType>
  <xs:complexType name="SomeStruct">
    <xs:sequence>
      <xs:element name="aString" type="MyString"/>
    </xs:sequence>
  </xs:complexType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """import
  std / options, xmlserde

type
  SomeStruct* = object
    aString* {.xmlName: "aString".}: MyString

  MyString* = string"""

    test "Choice object":
        const xsd = """
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xs:schema>
  <xs:simpleType name="MyString">
    <xs:restriction base="xs:string"/>
  </xs:simpleType>
  <xs:complexType name="SomeStruct">
    <xs:sequence>
      <xs:choice>
        <xs:element name="aString" type="MyString"/>
        <xs:element name="otherString" type="MyString"/>
      </xs:choice>
      <xs:element name="noChoice" type="MyString"/>
    </xs:sequence>
  </xs:complexType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """import
  std / options, xmlserde

type
  SomeStruct* = object
    aString* {.xmlName: "aString".}: Option[MyString]
    otherString* {.xmlName: "otherString".}: Option[MyString]
    noChoice* {.xmlName: "noChoice".}: MyString

  MyString* = string"""

    test "Enum":
        const xsd = """
<xs:schema>
  <xs:simpleType name="MyEnum">
    <xs:restriction base="xs:string">
      <xs:enumeration value="Val1"/>
      <xs:enumeration value="OtherVal"/>
    </xs:restriction>
  </xs:simpleType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """
import
  std / options, xmlserde

type
  MyEnum* {.pure.} = enum
    Val1, OtherVal
"""

    test "Arity of minimum 0 and maximum 1 produces optional type":
        const xsd = """
<xs:schema>
  <xs:simpleType name="MyString">
    <xs:restriction base="xs:string"/>
  </xs:simpleType>
  <xs:complexType name="MyObject">
    <xs:sequence>
      <xs:element name="one" type="MyString" minOccurs="0" maxOccurs="1"/>
    </xs:sequence>
  </xs:complexType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """
import
  std / options, xmlserde

type
  MyObject* = object
    one* {.xmlName: "one".}: Option[MyString]

  MyString* = string
"""

    test "Arity of above 1 or unbounded produces sequence type":
        const xsd = """
<xs:schema>
  <xs:simpleType name="MyString">
    <xs:restriction base="xs:string"/>
  </xs:simpleType>
  <xs:complexType name="MyObject">
    <xs:sequence>
      <xs:element name="one" type="MyString" minOccurs="0" maxOccurs="unbounded"/>
      <xs:element name="two" type="MyString" minOccurs="0" maxOccurs="2"/>
    </xs:sequence>
  </xs:complexType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """
import
  std / options, xmlserde

type
  MyObject* = object
    one* {.xmlName: "one".}: seq[MyString]
    two* {.xmlName: "two".}: seq[MyString]

  MyString* = string
"""

    test "Sequence type is generated even if in a 'choice'":
        const xsd = """
<xs:schema>
  <xs:simpleType name="MyString">
    <xs:restriction base="xs:string"/>
  </xs:simpleType>
  <xs:complexType name="MyObject">
    <xs:sequence>
      <xs:choice>
        <xs:element name="isSequence" type="MyString" minOccurs="0" maxOccurs="unbounded"/>
        <xs:element name="optFlattened" type="MyString" minOccurs="0" maxOccurs="1"/>
        <xs:element name="normalOpt" type="MyString"/>
      </xs:choice>
    </xs:sequence>
  </xs:complexType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """
import
  std / options, xmlserde

type
  MyObject* = object
    isSequence* {.xmlName: "isSequence".}: seq[MyString]
    optFlattened* {.xmlName: "optFlattened".}: Option[MyString]
    normalOpt* {.xmlName: "normalOpt".}: Option[MyString]

  MyString* = string
"""

    test "attributes":
        const xsd = """
<xs:schema>
  <xs:simpleType name="MyString">
    <xs:restriction base="xs:string"/>
  </xs:simpleType>
  <xs:complexType name="textFieldWithAttribute">
    <xs:simpleContent>
      <xs:extension base="MyString">
        <xs:attribute name="Ccy" type="MyString" use="required"/>
      </xs:extension>
    </xs:simpleContent>
  </xs:complexType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """
import
  std / options, xmlserde

type
  textFieldWithAttribute* = object
    text* {.xmlText.}: MyString
    Ccy* {.xmlName: "Ccy", xmlAttr.}: MyString

  MyString* = string
"""

    test "Non-identifier characters in fields and types are removed":
        const xsd = """
<xs:schema>
  <xs:simpleType name="My-Non.Ident^String">
    <xs:restriction base="xs:string"/>
  </xs:simpleType>
  <xs:complexType name="MyObject">
    <xs:sequence>
      <xs:element name="-weird^name" type="My-Non.Ident^String"/>
    </xs:sequence>
  </xs:complexType>
</xs:schema>
"""
        check xsd.xsdToNimStringify == """
import
  std / options, xmlserde

type
  MyObject* = object
    weirdname* {.xmlName: "-weird^name".}: MyNonIdentString

  MyNonIdentString* = string
"""
