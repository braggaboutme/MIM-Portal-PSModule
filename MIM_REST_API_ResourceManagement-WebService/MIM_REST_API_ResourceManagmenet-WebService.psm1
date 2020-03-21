#########################################################################################################
##   
##  MIM_Lithnet_API_Module version 0.4
##  
##  For use with the Lithnet ResourceManagement-WebService
##  https://github.com/lithnet/resourcemanagement-webservice/
##
##  Created By: Chris Bragg
##  https://github.com/braggaboutme/MIM-Portal-PSModule
##
##  Changelog:
##  v0.1 - 1/15/2020 - First Draft Created
##  v0.2 - 2/24/2020 - Commented out the 'Audit' switch for all commands. Added a do until statement to parse through multiple pages within a large query. Fixed typos and bugs.
##                     Also added the Update-MIMObject commandlet
##  v0.3 - 2/25/2020 - Added Audit switch back into script
##  v0.4 - 2/26/2020 - Corrected a typo and added an if statement before the while do loop
##
##  Audit mode is used to generate the full URL automatically without sending a REST call to the URL
##
#########################################################################################################
##
##   Description of commands:
##
##   Set-MIMCredentials      - This command is REQUIRED prior to running any other commands. Save the credentials as a variable (Ex: $creds) and pass that variable to the parameter '-Credentials' for each of the other commands  
##   Get-MIMUser             - This command will get the 'person' object from MIM. By default, only specific attributes are returned, if additional attributes are needed, use the -Attributes switch
##   Get-MIMGroup            - This command will get the 'group' object from MIM. By default, only specific attributes are returned, if additional attributes are needed, use the -Attributes switch
##   Add-MIMMember           - This command will add a user as a member of a group. At this time, only the object ID's are supported. To get the object ID of the user and group, run Get-MIMUser and Get-MIMGroup
##   Remove-MIMMember        - This command will remove a user from the membership of a group. At this time, only the object ID's are supported. To get the object ID of the user and group, run Get-MIMUser and Get-MIMGroup
##   Add-MIMOwner            - This command will add a user as an owner of a group. This will not affect the "Displayed Owner". At this time, only the object ID's are supported. To get the object ID of the user and group, run Get-MIMUser and Get-MIMGroup
##   Remove-MIMOwner         - This command will remove a user from being an owner of a group. This will not affect the "Displayed Owner". At this time, only the object ID's are supported. To get the object ID of the user and group, run Get-MIMUser and Get-MIMGroup
##   Update-MIMObject        - This command will update a specific attribute on a specific object. You MUST specify the Attribute and AttributeValue switch
##
##   Switches:
##
##  -Credentials      (Required)  - This switch is REQUIRED for all commands. You must pass the credentials to authenticate to MIM.
##  -Audit            (Optional)  - The Audit switch is helpful when using another application to send REST calls to the Lithnet Web Service. When the '-Audit' switch is used, the URL is generated and displayed but no other commands are executed.
##  -AccountName      (Optional)  - This switch is used to specify the AccountName of a resource.
##  -URL              (Required)  - This URL is used to define the URL that the Lithnet Web Service is listening on. If you use a port other than 80 or 443, you must specify that in the URL value.
##  -xpathquery       (Optional)  - This allows for the option of querying MIM objects with an xpath expression. This is used for advanced searches or for searches that return more than a single object.
##  -Attributes       (Optional)  - This switch allows you to specify attributes that you would like returned. This is in addition to the default attributes.
##  -AttributeValues  (Required)  - This switch is used with the Update-MIMObject command. This will allow you to specify the values of an attribute that you want to change.
##
#########################################################################################################
##
##   Example Commands Include:
##
##
##   Standalone Commands:
##
##   $creds = Set-MIMCredentials 
##   $cbragg = Get-MIMUser -AccountName 'chris.bragg' -Credentials $creds -URL "https://mim.domain.com:8080" -Attributes 'DisplayName,AccountName,Department'
##   $AccountingUsers = Get-MIMUser -xpathquery "[(ends-with(DN, 'OU=Accounting,OU=Users,DC=DOMAIN,DC=COM'))]" -Credentials $creds -URL "https://mim.domain.com:8080" -Attributes 'DisplayName,AccountName,Department'
##   $ABCGroup = Get-MIMGroup -AccountName 'ABCGroup' -Credentials $creds -URL "https://mim.domain.com:8080" -Attributes 'DisplayName,Owner,DisplayedOwner'
##   $AccountingGroups = Get-MIMGroup -xpathquery "[(starts-with(DisplayName, 'Accounting-'))]" -Credentials $creds -URL "https://mim.domain.com:8080" -Attributes 'DisplayName,AccountName,Department'
## 
##   Commands that are dependent on previous commands:
##
##   Add-MIMMember -URL https://mim.domain.com:8080 -Credentials $creds -GroupObjectID $ABCGroup.Results.ObjectID -UserObjectID $cbragg.Results.ObjectID
##   Add-MIMOwner -URL https://mim.domain.com:8080 -Credentials $creds -GroupObjectID $ABCGroup.Results.ObjectID -UserObjectID $cbragg.Results.ObjectID
##   Remove-MIMMember -URL https://mim.domain.com:8080 -Credentials $creds -GroupObjectID $ABCGroup.Results.ObjectID -UserObjectID $cbragg.Results.ObjectID
##   Remove-MIMOwner -URL https://mim.domain.com:8080 -Credentials $creds -GroupObjectID $ABCGroup.Results.ObjectID -UserObjectID $cbragg.Results.ObjectID
##   Update-MIMObject -ObjectID $userOID -Credentials $creds -url $url -Attribute $attribute -AttributeValue $attributevalue
## 
##   Example of a foreach loop
##
##   $users = Get-MIMUser -xpathquery "[(starts-with(Department, 'Accounting'))]" -Credentials $creds -URL "https://mim.domain.com:8080" -Attributes ObjectID
##   $users = Get-MIMUser -xpathquery "[(AccountEnabled = $true)]" -Credentials $creds -URL "https://mim.domain.com:8080" -Attributes "AccountEnabled,AccountName"
##
##   ForEach ($user in $users)
##   {
##   Add-MIMMember -URL https://mim.domain.com:8080 -Credentials $creds -GroupObjectID $ABCGroup.Results.ObjectID -UserObjectID $user.Results.ObjectID
##   }
## 
##
#########################################################################################################




#Needed for xpath encoding
Add-Type -AssemblyName System.Web

#############################
#Set MIM Credentials Function
#############################
#Used to set credentials to authenticate with MIM
function Set-MIMCredentials
    {

#Write-Host "Enter the account name to connect to MIM ex: domain\username" -ForegroundColor Yellow
        $Username = Read-Host "Enter the account name to connect to MIM ex: contoso\username"
        $password = Read-Host "Enter your Password" -AsSecureString 
#Converts credentials into a secure format that MIM can read
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $PassWord = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        $site_auth = "$($Username):$($PassWord)"
        $site_Bytes = [System.Text.Encoding]::UTF8.GetBytes($site_auth)
#$Site_EncodedAuth is the variable that is passed to MIM
        $Site_EncodedAuth = [Convert]::ToBase64String($site_Bytes)
        $global:Credentials = $Site_EncodedAuth
        $Credentials
        Clear-Variable username
        Clear-Variable password
        Clear-Variable bstr
        Clear-Variable Password
        Clear-Variable site_auth
        Clear-Variable site_bytes
        Clear-Variable site_EncodedAuth
    }

#############################
#Get MIM User Function
#############################

function Get-MIMUser
    {
 param(
    [Parameter()]
    $AccountName,
    [Parameter()]
    $xpathquery,
    [Parameter()]
    $Attributes,
    [Parameter()]
    $URL,
    [Parameter()]
    $Credentials,
    [Parameter()]
    [Switch]$Audit
 )
        $ObjectType = 'Person'
##
###If AccountName is used, do this Get-MIMUser Function
##
        if (-not ([string]::IsNullOrEmpty($AccountName)))
        {
        $xpath = "$($ObjectType)[AccountName='$($AccountName)']"
        $EncodedXPath = [System.Web.HttpUtility]::UrlEncode($xpath.tostring())
        $query = "?filter=/$($EncodedXpath)"
        
#Only stores this variable when the Attributes switch is used
        If (-not ([string]::IsNullOrEmpty($Attributes)))
        {        
        $SelectedAttributes = "&attributes=$($Attributes)"
        }
#Build API query
        $ConstructedURL = "$($URL)/v2/resources/$($query)$($SelectedAttributes)"
        If ($Audit.IsPresent)
            {
            return $ConstructedURL
            return
            }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        try{
        $user = Invoke-RestMethod -Uri ($ConstructedURL) -Method Get -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json"
        If ($user.TotalCount -eq 0)
        {
        Write-Host "Incorrect AccountName or account doesn't exist in MIM"
        }
            }
            catch [System.Management.Automation.RuntimeException]
            {
            Write-host "Either credentials are bad or the URL is incorrect"
            }
        return $user
        }
##
### IF $XPath switch is used, do this Get-MIMUser function
##
        elseif (-not ([string]::IsNullOrEmpty($xpathquery)))
        {
        $xpath = "$($ObjectType)$($xpathquery)"
#Encodes the xpath query. This is required for this type of query.
        $EncodedXPath = [System.Web.HttpUtility]::UrlEncode($xpath.tostring())
        $query = "?filter=/$($EncodedXpath)"
#Sets the number of items per page. This value should be more than the total number of items retrieved.
        $pages = 1000
        $pagesize = "&pageSize=$($pages)"
#Only stores this variable when the Attributes switch is used
        If (-not ([string]::IsNullOrEmpty($Attributes)))
        {
        $SelectedAttributes = "&attributes=$($Attributes)"
        }
#Build API query
        $ConstructedURL = "$($URL)/v2/resources/$($query)$($pagesize)$($SelectedAttributes)"
        try {
        $users = Invoke-RestMethod -Uri ($ConstructedURL) -Method Get -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json"
        If ($users.TotalCount -eq 0)
        {
        Write-Host "Incorrect AccountName or account doesn't exist in MIM"
        }
            }
            catch [System.Management.Automation.RuntimeException]
            {
            Write-host "Either credentials are bad or the URL is incorrect"
            }
            
#DO UNTIL Function to handle paging
            $arraylist = [System.Collections.ArrayList]@()
            $arraylist.Add($users) | Out-Null
            $urlnextpage = $users.nextpage
        if ($urlnextpage -ne $null)
        {
        do
            {
            $users = Invoke-RestMethod -uri ($urlnextpage) -Method Get -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json"
            $arraylist.Add($users) | Out-Null
            $urlnextpage = $users.NextPage
            }
                      
        until ($urlnextpage -eq $null)
        }
        
        
            $usersarray = $arraylist.results
            return $usersarray
                
        }
        Else
        {
        Write-Host "No valid paramaters found"
        }
}

#############################
#Get MIM Group Function
#############################

 function Get-MIMGroup
    {
 param(
    [Parameter()]
    $AccountName,
    [Parameter()]
    $xpathquery,
    [Parameter()]
    $Attributes,
    [Parameter()]
    $URL,
    [Parameter()]
    $Credentials,
    [Parameter()]
    [Switch]$Audit
 )
        $ObjectType = 'Group'
##
###If AccountName is used, do this Get-MIMGroup Function
##
        if (-not ([string]::IsNullOrEmpty($AccountName)))
        {
        $xpath = "$($ObjectType)[AccountName='$($AccountName)']"
        $EncodedXPath = [System.Web.HttpUtility]::UrlEncode($xpath.tostring())
        $query = "?filter=/$($EncodedXpath)"
        
        
#Only stores this variable when the Attributes switch is used
        If (-not ([string]::IsNullOrEmpty($Attributes)))
        {
        $SelectedAttributes = "&attributes=$($Attributes)"
        }
#Build API query
        $ConstructedURL = "$($URL)/v2/resources/$($query)$($SelectedAttributes)"
        If ($Audit -eq "true")
            {
            return $ConstructedURL
            return
            }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        try{
        $group = Invoke-RestMethod -Uri ($ConstructedURL) -Method Get -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json"
        If ($group.TotalCount -eq 0)
        {
        Write-Host "Incorrect AccountName or account doesn't exist in MIM"
        }
            }
            catch [System.Management.Automation.RuntimeException]
            {
            Write-host "Either credentials are bad or the URL is incorrect"
            }
            catch [System.Security.Authentication.AuthenticationException]
            {
            Write-Host "The remote certificate is invalide according to the validation procedure."
            }
            catch [System.Net.WebException]
            {
            Write-Host "Could not establish trust relationship for the SSL/TLS secure channel."
            }
            #catch [System.Management.Automation.ParameterBindingValidationException]
            #{
            #Write-Host "The URL or xpath query is incorrect"
            #}
            

        return $group
        }
        
##
### IF $XPath switch is used, do this Get-MIMUser function
##
        elseif (-not ([string]::IsNullOrEmpty($xpathquery)))
        {
        $xpath = "$($ObjectType)$($xpathquery)"
#Encodes the xpath query. This is required for this type of query.
        $EncodedXPath = [System.Web.HttpUtility]::UrlEncode($xpath.tostring())
        $query = "?filter=/$($EncodedXpath)"
#Sets the number of items per page. This value should be more than the total number of items retrieved.
        $pages = 1000
        $pagesize = "&pageSize=$($pages)"
#Only stores this variable when the Attributes switch is used
        If (-not ([string]::IsNullOrEmpty($Attributes)))
        {
        $SelectedAttributes = "&attributes=$($Attributes)"
        }
#Build API query
        $ConstructedURL = "$($URL)/v2/resources/$($query)$($pagesize)$($SelectedAttributes)"
        try {
        $groups = Invoke-RestMethod -Uri ($ConstructedURL) -Method Get -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json"
        If ($group.TotalCount -eq 0)
        {
        Write-Host "Incorrect AccountName or account doesn't exist in MIM"
        }
            }
            catch [System.Management.Automation.RuntimeException]
            {
            Write-host "Either credentials are bad or the URL is incorrect"
            }

#DO UNTIL Function to handle paging
            $arraylist = [System.Collections.ArrayList]@()
            $arraylist.Add($groups) | Out-Null
            $urlnextpage = $groups.nextpage
        if ($urlnextpage -ne $null)
        {
        do
            {
            $groups = Invoke-RestMethod -uri ($urlnextpage) -Method Get -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json"
            $arraylist.Add($groups) | Out-Null
            $urlnextpage = $groups.NextPage
            }
                      
        until ($urlnextpage -eq $null)
        }
        
     
            $groupsarray = $arraylist.results
            return $groupsarray
            
        }
        Else
        {
        Write-Host "No valid paramaters found"
        }
}

#############################
#Add MIM Owner Function
#############################

 function Add-MIMOwner{
 param(
    [Parameter()]
    $GroupObjectID,
    [Parameter()]
    $UserObjectID,
    [Parameter()]
    $URL,
    [Parameter()]
    $Credentials,
    [Parameter()]
    [Switch]$Audit
 )
    
    
#$APIURLGroup = "https://mim.domain.com:8080/v2/resources/a1c6ab78-c6bc-4595-94fd-2670a3a6182b/Owner/294b958b-1a38-4afe-a74b-de53b4e1c2ff/"
            $ConstructedURL = "$($URL)/v2/resources/$($GroupObjectID)/Owner/$($UserObjectID)/"
            If ($Audit -eq "true")
            {
            return $ConstructedURL
            return
            }
            #Invoke-WebRequest -Uri $APIURLGroup -Headers @{Authorization = "Basic $Site_EncodedAuth"} -ContentType "application/json" -UseBasicParsing -Method DELETE
            try {
            $user = Invoke-RestMethod -Uri ($ConstructedURL) -Method PUT -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json"
            If ($user.TotalCount -eq 0)
            {
            Write-Host "Incorrect AccountName or account doesn't exist in MIM"
            }
                }
            catch [System.Management.Automation.RuntimeException]
            {
            Write-host "Either credentials are bad or the URL is incorrect"
            }
            catch [System.Net.WebException]
            {
            Write-host "ERROR: Web Exception. The resource might be in an errored state."
            }

            return $user

            }
 
#############################
#Remove MIM Owner Function
#############################

 function Remove-MIMOwner{
 param(
    [Parameter()]
    $GroupObjectID,
    [Parameter()]
    $UserObjectID,
    [Parameter()]
    $URL,
    [Parameter()]
    $Credentials,
    [Parameter()]
    [Switch]$Audit
 )
    
    
#$APIURLGroup = "https://mim.domain.com:8080/v2/resources/a1c6ab78-c6bc-4595-94fd-2670a3a6182b/Owner/294b958b-1a38-4afe-a74b-de53b4e1c2ff/"
            $ConstructedURL = "$($URL)/v2/resources/$($GroupObjectID)/Owner/$($UserObjectID)/"
            
            If ($Audit -eq "true")
            {
            return $ConstructedURL
            return
            }
            #Invoke-WebRequest -Uri $APIURLGroup -Headers @{Authorization = "Basic $Site_EncodedAuth"} -ContentType "application/json" -UseBasicParsing -Method DELETE
            try {
            $user = Invoke-RestMethod -Uri ($ConstructedURL) -Method DELETE -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json"
            If ($user.TotalCount -eq 0)
            {
            Write-Host "Incorrect AccountName or account doesn't exist in MIM"
            }
                }
            catch [System.Management.Automation.RuntimeException]
            {
            Write-host "Either credentials are bad or the URL is incorrect"
            }

            return $user

            }
 
#############################
#Add MIM Member Function
#############################

 function Add-MIMMember{
 param(
    [Parameter()]
    $GroupObjectID,
    [Parameter()]
    $UserObjectID,
    [Parameter()]
    $URL,
    [Parameter()]
    $Credentials,
    [Parameter()]
    [Switch]$Audit
 )
    
    
#$APIURLGroup = "https://mim.domain.com:8080/v2/resources/a1c6ab78-c6bc-4595-94fd-2670a3a6182b/Manually-ManagedMembership/294b958b-1a38-4afe-a74b-de53b4e1c2ff/"
            $ConstructedURL = "$($URL)/v2/resources/$($GroupObjectID)/Manually-ManagedMembership/$($UserObjectID)/"
            If ($Audit -eq "true")
            {
            return $ConstructedURL
            return
            }
            #Invoke-WebRequest -Uri $APIURLGroup -Headers @{Authorization = "Basic $Site_EncodedAuth"} -ContentType "application/json" -UseBasicParsing -Method DELETE
            try {
            $user = Invoke-RestMethod -Uri ($ConstructedURL) -Method PUT -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json"
            If ($user.TotalCount -eq 0)
            {
            Write-Host "Incorrect AccountName or account doesn't exist in MIM"
            }
                }
            catch [System.Management.Automation.RuntimeException] 
            {
            Write-host "Either credentials are bad or the URL is incorrect"
            }

            return $user

            }

#############################
#Remove MIM Member Function
#############################

 function Remove-MIMMember{
 param(
    [Parameter()]
    $GroupObjectID,
    [Parameter()]
    $UserObjectID,
    [Parameter()]
    $URL,
    [Parameter()]
    $Credentials,
    [Parameter()]
    [Switch]$Audit
 )
    
    
#$APIURLGroup = "https://mim.domain.com:8080/v2/resources/a1c6ab78-c6bc-4595-94fd-2670a3a6182b/Manually-ManagedMembership/294b958b-1a38-4afe-a74b-de53b4e1c2ff/"
            $ConstructedURL = "$($URL)/v2/resources/$($GroupObjectID)/Manually-ManagedMembership/$($UserObjectID)/"
            If ($Audit -eq "true")
            {
            return $ConstructedURL
            return
            }
            #Invoke-WebRequest -Uri $APIURLGroup -Headers @{Authorization = "Basic $Site_EncodedAuth"} -ContentType "application/json" -UseBasicParsing -Method DELETE
            try {
            $user = Invoke-RestMethod -Uri ($ConstructedURL) -Method DELETE -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json"
            If ($user.TotalCount -eq 0)
            {
            Write-Host "Incorrect AccountName or account doesn't exist in MIM"
            }
                }
            catch [System.Management.Automation.RuntimeException] 
            {
            Write-host "Either credentials are bad or the URL is incorrect"
            }

            return $user

            }
 


#############################
#Update MIM Object
#############################

 function Update-MIMObject{
 param(
    [Parameter()]
    $ObjectID,
    [Parameter()]
    $URL,
    [Parameter()]
    $Credentials,
    [Parameter()]
    $Attribute,
    [Parameter()]
    $AttributeValue,
    [Parameter()]
    [Switch]$Audit
 )
    
    
            $ConstructedURL = "$($URL)/v2/resources/$($ObjectID)/"
            $body = @{

            $($Attribute)="$AttributeValue"
            
            }

            $jsonbody = $body | ConvertTo-Json

            If ($Audit.IsPresent)
            {
            return $ConstructedURL
            return
            }
            try {
            $response = Invoke-RestMethod -Uri ($ConstructedURL) -Method PATCH -Headers @{Authorization = "Basic $Credentials"} -ContentType "application/json" -Body $jsonbody
            If ($response.TotalCount -eq 0)
            {
            Write-Host "Incorrect AccountName or account doesn't exist in MIM"
            }
                }
            catch [System.Management.Automation.RuntimeException] 
            {
            Write-host "Either credentials are bad or the URL is incorrect"
            }

            return $response

            }
