 # get AD schema path
$adSchema = (Get-ADRootDSE).schemaNamingContext
 
# get user schema
$userSchema = Get-ADObject -SearchBase $adSchema -Filter "Name -eq 'User'"


# Generate OID
$Prefix = "1.2.840.113556.1.8000.2554"
$GUID = [System.Guid]::NewGuid().ToString()
$GUIDPart = @()
$GUIDPart += [UInt64]::Parse($GUID.SubString(0,4), "AllowHexSpecifier")
$GUIDPart += [UInt64]::Parse($GUID.SubString(4,4), "AllowHexSpecifier")
$GUIDPart += [UInt64]::Parse($GUID.SubString(9,4), "AllowHexSpecifier")
$GUIDPart += [UInt64]::Parse($GUID.SubString(14,4), "AllowHexSpecifier")
$GUIDPart += [UInt64]::Parse($GUID.SubString(19,4), "AllowHexSpecifier")
$GUIDPart += [UInt64]::Parse($GUID.SubString(24,6), "AllowHexSpecifier")
$GUIDPart += [UInt64]::Parse($GUID.SubString(30,6), "AllowHexSpecifier")
$OID = [String]::Format("{0}.{1}.{2}.{3}.{4}.{5}.{6}.{7}", $Prefix, $GUIDPart[0], $GUIDPart[1], $GUIDPart[2], $GUIDPart[3], $GUIDPart[4], $GUIDPart[5], $GUIDPart[6])



# set the short name for custom attribute with no spaces
$attributeName = "PrimaryWorkstation"
# set the short description for custom attribute
$attributeDesc = "Primary Workstation Name"
# oMSyntax is "64" for String (Unicode). Refer this link for other types: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/7cda533e-d7a4-4aec-a517-91d02ff4a1aa
$oMSyntax = 64
# attributeSyntax is "2.5.5.12" for String (Unicode). Refer this link for other types: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/7cda533e-d7a4-4aec-a517-91d02ff4a1aa
$attributeSyntax = "2.5.5.12"
# set the indexable value to "1" if you want AD to index this attribute. set this only if you would be querying this AD attribute a lot.
$indexable = 0
# build custom attributes hashtable
$adAttributes = @{
  lDAPDisplayName = $attributeName;
  adminDescription = $attributeDesc;
  attributeId = $OID;
  oMSyntax = $oMSyntax;
  attributeSyntax = $attributeSyntax;
  searchflags = $indexable
}


# Create the custom attribute in AD schema
New-ADObject -Name  $attributeName -Type attributeSchema -Path $adSchema -OtherAttributes $adAttributes
 
# add the custom attribute to user class
$userSchema | Set-ADObject -Add @{mayContain = $attributeName}  

