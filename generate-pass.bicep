param secretName string
param uamiResourceId string
param keyVaultName string

module vmPassword 'br/public:avm/res/resources/deployment-script:0.5.2' = {
  params: {
    name: secretName
    kind: 'AzurePowerShell'
    azPowerShellVersion: '7.2'
    managedIdentities: {
      userAssignedResourceIds: [
        uamiResourceId
      ]
    }
    timeout: 'PT30M'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnExpiration'
    arguments: '"${keyVaultName}" "${secretName}" "$%@" "30"'
    scriptContent: '''
      param(
        [string]$vaultName,
        [string]$secretName,
        [string]$excludeChars,
        [int]$passwordLength
      )

      function New-RandomPassword {
          param(
              [int]$Length = 30,
              [string]$ExcludeChars = ""
          )

          if ($Length -lt 1) {
              throw "Password length must be at least 1."
          }

          # Define character groups
          $charGroups = @{
              lowercase = 'abcdefghijklmnopqrstuvwxyz'
              uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
              digits    = '0123456789'
              specials  = '!@#$%^&*()-_=+'
          }

          $excludeSet = $ExcludeChars.ToCharArray()

          # Filter out excluded characters from each group
          $validGroups = @{}
          foreach ($group in $charGroups.Keys) {
              $filtered = ($charGroups[$group].ToCharArray() | Where-Object { $_ -notin $excludeSet }) -join ''
              if ($filtered) {
                  $validGroups[$group] = $filtered
              }
          }

          if ($validGroups.Count -eq 0) {
              throw "All character groups were excluded. Cannot generate password."
          }

          # Always include one char from each available group (if possible)
          $requiredChars = @()
          foreach ($group in $validGroups.Values) {
              $requiredChars += Get-Random -InputObject $group.ToCharArray()
          }

          $remainingLength = $Length - $requiredChars.Count
          if ($remainingLength -lt 0) {
              throw "Password length is too short for the number of required character types: $($requiredChars.Count)"
          }

          # Build the full character set from remaining groups
          $allChars = ($validGroups.Values -join '').ToCharArray()

          # Get remaining random characters
          $randomChars = 1..$remainingLength | ForEach-Object { Get-Random -InputObject $allChars }

          # Combine and shuffle
          $finalPassword = ($requiredChars + $randomChars) | Get-Random -Count $Length
          return -join $finalPassword
      }

      # Authenticate using the managed identity
      Connect-AzAccount -Identity

      $passwordSecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -ErrorAction SilentlyContinue
      if ($null -ne $passwordSecret) {
          Write-Host "Secret already exists, reusing."
      } else {
          Write-Host "Secret not found, generating new password."

          $password = New-RandomPassword -Length $passwordLength -ExcludeChars '$excludeChars'

          Set-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -SecretValue (ConvertTo-SecureString -String $password -AsPlainText -Force) | Out-Null
      }
    '''
  }
}


output secretName string = secretName
