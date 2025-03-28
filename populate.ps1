param (
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [string]$TargetOU,

    [switch]$WhatIf
)

# Check if the CSV file exists
if (-not (Test-Path $CsvPath)) {
    Write-Error "❌ The specified CSV file does not exist: $CsvPath"
    exit 1
}

# Check if the specified OU exists in Active Directory
try {
    $ouExists = Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$TargetOU)" -ErrorAction Stop
} catch {
    Write-Error "❌ The specified OU does not exist in Active Directory: $TargetOU"
    exit 1
}

# Load the CSV data
$users = Import-Csv -Path $CsvPath

# Check for required columns
$requiredColumns = @("first_name", "last_name", "password")
foreach ($col in $requiredColumns) {
    if (-not ($users | Get-Member -Name $col)) {
        Write-Error "❌ Missing required column '$col' in the CSV."
        exit 1
    }
}

# Process each user
foreach ($user in $users) {
    $firstName = $user.first_name.Trim()
    $lastName = $user.last_name.Trim()
    $passwordPlain = $user.password

    # Generate sAMAccountName: first 3 letters of first name + first 3 letters of last name
    $prefixFirst = ($firstName.Substring(0, [Math]::Min(3, $firstName.Length))).ToLower()
    $prefixLast  = ($lastName.Substring(0, [Math]::Min(3, $lastName.Length))).ToLower()
    $login = $prefixFirst + $prefixLast

    $upn = "$login@entreprise.local"
    $displayName = "$firstName $lastName"

    # Check if the user already exists in Active Directory
    $existingUser = Get-ADUser -Filter { SamAccountName -eq $login } -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Error "❌ User '$login' already exists in Active Directory. Aborting script."
        exit 1
    }

    # Convert plain password to SecureString
    $securePassword = ConvertTo-SecureString $passwordPlain -AsPlainText -Force

    # Dry Run Mode
    if ($WhatIf) {
        Write-Host "🔍 [WhatIf] User would be created: $login in '$TargetOU'" -ForegroundColor Cyan
    } else {
        try {
            New-ADUser -Name $displayName `
                       -GivenName $firstName `
                       -Surname $lastName `
                       -SamAccountName $login `
                       -UserPrincipalName $upn `
                       -DisplayName $displayName `
                       -AccountPassword $securePassword `
                       -Enabled $true `
                       -Path $TargetOU

            Write-Host "✅ User created: $login" -ForegroundColor Green
        } catch {
            Write-Error "❌ Error creating user '$login': $_"
        }
    }
}
