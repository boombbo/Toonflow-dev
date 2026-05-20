param(
  [string]$ApiUrl = "http://localhost:10588/api/setting/vendorConfig/modelTest/imageTest",
  [string]$VendorListUrl = "http://localhost:10588/api/setting/vendorConfig/getVendorList",
  [string]$UpdateInputsUrl = "http://localhost:10588/api/setting/vendorConfig/updateVendorInputs",
  [string]$BaseUrl = "https://api.xxiaozhi.com/v1",
  [string]$ProviderMode = "xiaozhi_chat_i2i",
  [string]$ExpectedRequestModel = "gpt-image-2"
)

$ErrorActionPreference = "Stop"

function ConvertFrom-JsonSafe {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
  try { return $Text | ConvertFrom-Json } catch { return $null }
}

function Read-ErrorBody {
  param([object]$Exception)
  if ($Exception.Response) {
    try {
      $reader = [System.IO.StreamReader]::new($Exception.Response.GetResponseStream())
      return $reader.ReadToEnd()
    } catch {
      return ""
    }
  }
  return ""
}

function Invoke-BackendJson {
  param(
    [string]$Uri,
    [object]$Body
  )
  $json = $Body | ConvertTo-Json -Depth 12
  return Invoke-WebRequest -Uri $Uri -Method Post -ContentType "application/json" -Body $json -TimeoutSec 360
}

function Get-BackendLogLines {
  param([int]$Skip = 0)
  $logPath = Join-Path (Get-Location) ".toonflow-dev\logs\backend.log"
  if (!(Test-Path -LiteralPath $logPath)) { return @() }
  $lines = Get-Content -LiteralPath $logPath
  if ($Skip -le 0 -or $Skip -ge $lines.Count) { return $lines }
  if ($Skip -ge $lines.Count) { return @() }
  return @($lines[$Skip..($lines.Count - 1)])
}

function Get-LogField {
  param(
    [string]$Line,
    [string]$Key
  )
  if ([string]::IsNullOrWhiteSpace($Line)) { return "" }
  $pattern = "(?:^|[ `t])$([regex]::Escape($Key))=([^\s]+)"
  $m = [regex]::Match($Line, $pattern)
  if ($m.Success) { return $m.Groups[1].Value }
  return ""
}

function Find-LastLogLine {
  param(
    [string[]]$Lines,
    [string]$Pattern
  )
  $matches = @($Lines | Select-String -Pattern $Pattern)
  if ($matches.Count -gt 0) {
    return [string]$matches[-1].Line
  }
  return ""
}

function Get-ImageBytesFromDataUrl {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return 0 }
  if ($Text -match "^data:image/[^;]+;base64,(.+)$") {
    return [math]::Floor(($Matches[1].Length * 3) / 4)
  }
  return 0
}

function Get-ImageBytesFromUrl {
  param([string]$Url)
  if ([string]::IsNullOrWhiteSpace($Url)) { return 0 }
  $tempPath = Join-Path $env:TEMP ("toonflow-xiaozhi-" + [Guid]::NewGuid().ToString("N") + ".img")
  try {
    Invoke-WebRequest -Uri $Url -OutFile $tempPath -TimeoutSec 120 | Out-Null
    if (Test-Path -LiteralPath $tempPath) {
      return [int64](Get-Item -LiteralPath $tempPath).Length
    }
  } catch {
    return 0
  } finally {
    if (Test-Path -LiteralPath $tempPath) {
      Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
  }
  return 0
}

function Get-ReferenceImage {
  $downloads = Join-Path $HOME "Downloads"
  if (!(Test-Path -LiteralPath $downloads)) {
    throw "Downloads directory not found: $downloads"
  }
  $source = Get-ChildItem -LiteralPath $downloads -File |
    Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp)$' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (!$source) {
    throw "No png/jpg/jpeg/webp image found in Downloads."
  }

  $repoRoot = Get-Location
  $assetDir = Join-Path $repoRoot ".toonflow-dev\test-assets"
  New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
  $ext = $source.Extension.ToLowerInvariant()
  $referencePath = Join-Path $assetDir "gpt-image2-xiaozhi-chat-reference$ext"
  Copy-Item -LiteralPath $source.FullName -Destination $referencePath -Force

  $mime = switch ($ext) {
    ".jpg" { "image/jpeg" }
    ".jpeg" { "image/jpeg" }
    ".webp" { "image/webp" }
    default { "image/png" }
  }

  $bytes = [System.IO.File]::ReadAllBytes($referencePath)
  $imageBase64 = "data:$mime;base64,$([Convert]::ToBase64String($bytes))"

  [pscustomobject]@{
    referenceImagePath = $referencePath
    imageBase64 = $imageBase64
    imageBase64Length = $imageBase64.Length
    referenceImageBytes = $bytes.Length
    mime = $mime
  }
}

function Mask-Key([string]$Key) {
  if ([string]::IsNullOrWhiteSpace($Key)) { return "" }
  if ($Key.Length -le 10) { return "sk-***" }
  return "$($Key.Substring(0, 7))***$($Key.Substring($Key.Length - 4))"
}

$AspectCases = @(
  [pscustomobject]@{ aspectRatio = "1:1"; openAiSize = "1024x1024"; size = "1K" },
  [pscustomobject]@{ aspectRatio = "16:9"; openAiSize = "1792x1024"; size = "1K" },
  [pscustomobject]@{ aspectRatio = "9:16"; openAiSize = "1024x1792"; size = "1K" }
)

$vendorResp = Invoke-WebRequest -Uri $VendorListUrl -Method Post -ContentType "application/json" -Body "{}" -TimeoutSec 120
$vendors = (ConvertFrom-JsonSafe $vendorResp.Content).data
$vendor = $vendors | Where-Object { $_.id -eq "third_party_image_api" }
if (!$vendor) { throw "third_party_image_api not found" }

$originalInputs = [ordered]@{}
foreach ($p in $vendor.inputValues.PSObject.Properties) {
  $originalInputs[$p.Name] = [string]$p.Value
}

$updatedInputs = [ordered]@{}
foreach ($k in $originalInputs.Keys) {
  $updatedInputs[$k] = $originalInputs[$k]
}
$updatedInputs.baseUrl = $BaseUrl
$updatedInputs.providerMode = $ProviderMode

try {
  Invoke-BackendJson -Uri $UpdateInputsUrl -Body @{ id = "third_party_image_api"; inputValues = $updatedInputs } | Out-Null
} catch {
  throw "Failed to update vendor inputs to xiaozhi. $($_.Exception.Message)"
}

function Invoke-ModelTest {
  param(
    [string]$Mode,
    [string]$Prompt,
    [string]$ClientRequestId,
    [string]$ImageBase64 = "",
    [string]$OpenAiSize = "1024x1024",
    [string]$AspectRatio = "1:1",
    [string]$Size = "1K"
  )
  $body = [ordered]@{
    id = "third_party_image_api"
    modelName = $ExpectedRequestModel
    prompt = $Prompt
    openAiSize = $OpenAiSize
    aspectRatio = $AspectRatio
    size = $Size
    clientRequestId = $ClientRequestId
    testMode = $Mode
  }
  if ($Mode -eq "singleImage" -and $ImageBase64) {
    $body.imageBase64 = $ImageBase64
  }
  $logCountBefore = (Get-BackendLogLines).Count
  $resp = $null
  $httpStatus = $null
  $responseContentType = ""
  $rawBody = ""
  try {
    $resp = Invoke-WebRequest -Uri $ApiUrl -Method Post -ContentType "application/json" -Body ($body | ConvertTo-Json -Depth 10) -TimeoutSec 420
    $httpStatus = [int]$resp.StatusCode
    $responseContentType = [string]$resp.Headers["Content-Type"]
    $rawBody = [string]$resp.Content
  } catch {
    $err = $_
    if ($err.Exception.Response) {
      $httpStatus = [int]$err.Exception.Response.StatusCode
      try { $responseContentType = [string]$err.Exception.Response.Headers["Content-Type"] } catch { $responseContentType = "" }
      $rawBody = Read-ErrorBody $err.Exception
      if (!$rawBody -and $err.ErrorDetails -and $err.ErrorDetails.Message) {
        $rawBody = [string]$err.ErrorDetails.Message
      }
    } else {
      $rawBody = [string]$err.Exception.Message
    }
  }

  $parsed = ConvertFrom-JsonSafe $rawBody
  Start-Sleep -Milliseconds 300
  $backendLines = Get-BackendLogLines -Skip $logCountBefore
  $requestMarker = if ($Mode -eq "singleImage") {
    "xiaozhi_chat_i2i_ok providerMode=xiaozhi_chat_i2i"
  } else {
    "openai_images POST https://api.xxiaozhi.com/v1/images/generations endpointUsed=/images/generations"
  }
  $vendorLine = Find-LastLogLine -Lines $backendLines -Pattern $requestMarker
  if (!$vendorLine) {
    $vendorLine = Find-LastLogLine -Lines $backendLines -Pattern "providerMode=$ProviderMode"
  }

  $providerModeLog = Get-LogField -Line $vendorLine -Key "providerMode"
  $endpointUsed = Get-LogField -Line $vendorLine -Key "endpointUsed"
  $requestModel = Get-LogField -Line $vendorLine -Key "requestModel"
  if (!$requestModel) { $requestModel = Get-LogField -Line $vendorLine -Key "body.model" }
  if (!$requestModel) { $requestModel = Get-LogField -Line $vendorLine -Key "model.modelName" }
  $responseModel = Get-LogField -Line $vendorLine -Key "responseModel"
  $extractedImageUrl = Get-LogField -Line $vendorLine -Key "extractedImageUrl"
  $imageBytes = Get-LogField -Line $vendorLine -Key "imageBytes"
  if (-not $imageBytes -and $parsed -and $parsed.data -is [string] -and $parsed.data -match '^https?://') {
    $imageBytes = Get-ImageBytesFromUrl $parsed.data
  }
  if (!$imageBytes -and $parsed -and $parsed.data -is [string]) {
    $imageBytes = Get-ImageBytesFromDataUrl $parsed.data
  }
  $success = ($httpStatus -eq 200 -and $parsed -and ($parsed.code -eq 200) -and [string]::IsNullOrWhiteSpace($parsed.message) -eq $false -and ($parsed.data -is [string]))
  $failure = if ($success) { "" } else { "failure" }

  [pscustomobject]@{
    mode = $Mode
    aspectRatio = $AspectRatio
    openAiSize = $OpenAiSize
    size = $Size
    providerMode = $providerModeLog
    endpointUsed = $endpointUsed
    requestModel = $requestModel
    responseModel = $responseModel
    requestModelUnchanged = ($requestModel -eq $ExpectedRequestModel)
    extractedImageUrl = $extractedImageUrl
    imageBytes = if ($imageBytes) { [int]$imageBytes } else { 0 }
    httpStatus = $httpStatus
    responseContentType = $responseContentType
    rawResponseBodyPreview = if ($rawBody) { $rawBody.Substring(0, [Math]::Min(1500, $rawBody.Length)) } else { "" }
    success = $success
    failure = $failure
    responseCode = $parsed.code
    responseMessage = $parsed.message
    clientRequestId = $ClientRequestId
  }
}

try {
  $textPrompt = "A clean studio illustration of a red apple on a white table, high detail, neutral background."
  $textResults = @()
  foreach ($case in $AspectCases) {
    $textClientRequestId = "xiaozhi-text-$($case.aspectRatio.Replace(':', 'x'))-$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
    $textResults += Invoke-ModelTest -Mode "text" -Prompt $textPrompt -ClientRequestId $textClientRequestId -OpenAiSize $case.openAiSize -AspectRatio $case.aspectRatio -Size $case.size
  }

  $reference = Get-ReferenceImage
  $i2iPrompt = "Use the uploaded reference image as an identity reference. Create a clean full-body original anime character design on a simple neutral background. Preserve the main identity silhouette, face structure, hairstyle, outfit structure, and signature wearable items from the reference image. No text, no watermark, no UI."
  $i2iResults = @()
  foreach ($case in $AspectCases) {
    $i2iClientRequestId = "xiaozhi-i2i-$($case.aspectRatio.Replace(':', 'x'))-$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
    $i2iResults += Invoke-ModelTest -Mode "singleImage" -Prompt $i2iPrompt -ClientRequestId $i2iClientRequestId -ImageBase64 $reference.imageBase64 -OpenAiSize $case.openAiSize -AspectRatio $case.aspectRatio -Size $case.size
  }

  $report = [ordered]@{
    baseUrl = $BaseUrl
    providerMode = $ProviderMode
    expectedRequestModel = $ExpectedRequestModel
    apiKey = Mask-Key $originalInputs.apiKey
    textToImage = $textResults
    imageToImage = $i2iResults
    requestModelUnchanged = (@($textResults + $i2iResults | Where-Object { $_.requestModelUnchanged -ne $true }).Count -eq 0)
    timestamp = (Get-Date).ToString("o")
  }

  $reportPath = Join-Path (Get-Location) ".toonflow-dev\gpt-image2-xiaozhi-chat-last-run.json"
  $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8
  $report | ConvertTo-Json -Depth 12
}
finally {
  try {
    Invoke-BackendJson -Uri $UpdateInputsUrl -Body @{ id = "third_party_image_api"; inputValues = $originalInputs } | Out-Null
  } catch {
    Write-Host "Warning: failed to restore original vendor inputs: $($_.Exception.Message)"
  }
}
