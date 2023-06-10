$PSDefaultParameterValues['Stop-Process:ErrorAction'] = [System.Management.Automation.ActionPreference]::SilentlyContinue

function Get-File
{
	param (
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[System.Uri]
		$Uri,
		[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[System.IO.FileInfo]
		$TargetFile,
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[Int32]
		$BufferSize = 1,
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('KB, MB')]
		[String]
		$BufferUnit = 'MB',
		[Parameter(ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('KB, MB')]
		[Int32]
		$Timeout = 10000
	)

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$useBitTransfer = $null -ne (Get-Module -Name BitsTransfer -ListAvailable) -and ($PSVersionTable.PSVersion.Major -le 5) -and ((Get-Service -Name BITS).StartType -ne [System.ServiceProcess.ServiceStartMode]::Disabled)

	if ($useBitTransfer)
	{
		Write-Information -MessageData 'Using a fallback BitTransfer method since you are running Windows PowerShell'
		Start-BitsTransfer -Source $Uri -Destination "$($TargetFile.FullName)"
	}
	else
	{
		$request = [System.Net.HttpWebRequest]::Create($Uri)
		$request.set_Timeout($Timeout) #15 second timeout
		$response = $request.GetResponse()
		$totalLength = [System.Math]::Floor($response.get_ContentLength() / 1024)
		$responseStream = $response.GetResponseStream()
		$targetStream = New-Object -TypeName ([System.IO.FileStream]) -ArgumentList "$($TargetFile.FullName)", Create
		switch ($BufferUnit)
		{
			'KB' { $BufferSize = $BufferSize * 1024 }
			'MB' { $BufferSize = $BufferSize * 1024 * 1024 }
			Default { $BufferSize = 1024 * 1024 }
		}
		Write-Verbose -Message "Buffer size: $BufferSize B ($($BufferSize/("1$BufferUnit")) $BufferUnit)"
		$buffer = New-Object byte[] $BufferSize
		$count = $responseStream.Read($buffer, 0, $buffer.length)
		$downloadedBytes = $count
		$downloadedFileName = $Uri -split '/' | Select-Object -Last 1
		while ($count -gt 0)
		{
			$targetStream.Write($buffer, 0, $count)
			$count = $responseStream.Read($buffer, 0, $buffer.length)
			$downloadedBytes = $downloadedBytes + $count
			Write-Progress -Activity "Downloading file '$downloadedFileName'" -Status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes / 1024)) / $totalLength) * 100)
		}
		
		Write-Progress -Activity "Finished downloading file '$downloadedFileName'"
		
		$targetStream.Flush()
		$targetStream.Close()
		$targetStream.Dispose()
		$responseStream.Dispose()
	}
}

try
{
	$spotifySetupFilePath = Join-Path -Path $PWD -ChildPath 'SpotifyFullSetup.exe'
	$uri = 'https://download.scdn.co/SpotifyFullSetup.exe'
	Get-File -Uri $uri -TargetFile "$spotifySetupFilePath"
}
catch
{
	Write-Output $_
 	Start-Sleep
}
