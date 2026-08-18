$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
  function Invoke-Tool([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "$Executable $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
  }

  Invoke-Tool "moon" @("fmt", "--check")
  Invoke-Tool "moon" @("check", "--target", "all", "--deny-warn", "--fmt")
  Invoke-Tool "moon" @("info", "--target", "all")
  Invoke-Tool "git" @("diff", "--exit-code")
  Invoke-Tool "moon" @("test", "--target", "all", "--deny-warn")
  Invoke-Tool "moon" @("build", "--target", "all", "--deny-warn")
  Invoke-Tool "moon" @("run", "--target", "native", "cmd/main")
}
finally {
  Pop-Location
}

