﻿function Invoke-TmfAgreement
{
	[CmdletBinding()]
	Param ( )
		
	
	begin
	{
		$componentName = "agreements"
		if (!$script:desiredConfiguration[$componentName]) {
			Stop-PSFFunction -String "TMF.NoDefinitions" -StringValues "Group"
			return
		}
		Test-GraphConnection -Cmdlet $PSCmdlet
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		$testResults = Test-TmfAgreement -Cmdlet $PSCmdlet

		foreach ($result in $testResults) {
			Beautify-TmfTestResult -TestResult $result -FunctionName $MyInvocation.MyCommand
			switch ($result.ActionType) {
				"Create" {
					$requestUrl = "$script:graphBaseUrl/agreements"
					$requestMethod = "POST"
					$requestBody = @{						
						"displayName" = $result.DesiredConfiguration.displayName
					}
					try {
						"isViewingBeforeAcceptanceRequired", "isPerDeviceAcceptanceRequired", "userReacceptRequiredFrequency", "termsExpiration", "files" | foreach {
							if ($result.DesiredConfiguration.Properties() -contains "$_") {
								switch ($_) {
									"files" {										
										$configPath = (Get-TmfActiveConfiguration | ? {$_.Name -eq $result.DesiredConfiguration.sourceConfig}).Path
										$requestBody["files"] = @($result.DesiredConfiguration.files | foreach {
											$file = $_ | select fileName, language, isDefault
											$filePath = "{0}/agreements/{1}" -f $configPath, $_.filePath
											$data = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($filePath))
											Add-Member -InputObject $file -MemberType NoteProperty -Name "fileData" -Value @{ data = $data }
											return $file
										})
									}
									default { $requestBody[$_] = $result.DesiredConfiguration.$_ }
								}								
							}
						}
						
						$requestBody = $requestBody | ConvertTo-Json -ErrorAction Stop -Depth 8
						Write-PSFMessage -Level Verbose -String "TMF.Invoke.SendingRequestWithBody" -StringValues $requestMethod, $requestUrl, $requestBody
						Invoke-MgGraphRequest -Method $requestMethod -Uri $requestUrl -Body $requestBody | Out-Null
					}
					catch {
						Write-PSFMessage -Level Error -String "TMF.Invoke.ActionFailed" -StringValues $result.Tenant, $result.ResourceType, $result.ResourceName, $result.ActionType
						throw $_
					}
				}
				"Delete" {
					$requestUrl = "$script:graphBaseUrl/agreements/{0}" -f $result.GraphResource.Id
					$requestMethod = "DELETE"
					try {
						Write-PSFMessage -Level Verbose -String "TMF.Invoke.SendingRequest" -StringValues $requestMethod, $requestUrl
						#Invoke-MgGraphRequest -Method $requestMethod -Uri $requestUrl
					}
					catch {
						Write-PSFMessage -Level Error -String "TMF.Invoke.ActionFailed" -StringValues $result.Tenant, $result.ResourceType, $result.ResourceName, $result.ActionType
						throw $_
					}
				}
				"Update" {					
					$requestUrl = "$script:graphBaseUrl/agreements/{0}" -f $result.GraphResource.Id
					$requestMethod = "PATCH"
					$requestBody = @{}
					try {
						foreach ($change in $result.Changes) {						
							switch ($change.Property) {								
								default {
									foreach ($action in $change.Actions.Keys) {
										switch ($action) {
											"Set" { $requestBody[$change.Property] = $change.Actions[$action] }
										}
									}									
								}
							}							
						}

						if ($requestBody.Keys -gt 0) {
							$requestBody = $requestBody | ConvertTo-Json -ErrorAction Stop
							Write-PSFMessage -Level Verbose -String "TMF.Invoke.SendingRequestWithBody" -StringValues $requestMethod, $requestUrl, $requestBody
							#Invoke-MgGraphRequest -Method $requestMethod -Uri $requestUrl -Body $requestBody
						}
					}
					catch {
						Write-PSFMessage -Level Error -String "TMF.Invoke.ActionFailed" -StringValues $result.Tenant, $result.ResourceType, $result.ResourceName, $result.ActionType
						throw $_
					}
				}
				"NoActionRequired" { }
				default {
					Write-PSFMessage -Level Warning -String "TMF.Invoke.ActionTypeUnknown" -StringValues $result.ActionType
				}				
			}
			Write-PSFMessage -Level Host -String "TMF.Invoke.ActionCompleted" -StringValues $result.Tenant, $result.ResourceType, $result.ResourceName, (Get-ActionColor -Action $result.ActionType), $result.ActionType
		}		
	}
	end
	{
		
	}
}