function Resolve-NumblopGodot {
    param([string]$GodotPath = "")

    if ($GodotPath) {
        if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
            throw "Godot executable not found: $GodotPath"
        }
        return (Resolve-Path -LiteralPath $GodotPath).Path
    }

    foreach ($name in @("godot4", "godot")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    $repoRoot = Split-Path $PSScriptRoot -Parent
    $godotRoot = Join-Path (Split-Path $repoRoot -Parent) "Godot"
    $candidate = Get-ChildItem -LiteralPath $godotRoot -File -ErrorAction SilentlyContinue |
        Where-Object Name -Match '^Godot.*_console\.exe$' |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($null -ne $candidate) {
        return $candidate.FullName
    }

    throw "Godot was not found on PATH or in the sibling Godot directory."
}

function Invoke-NumblopGodot {
    param(
        [Parameter(Mandatory)] [string]$Godot,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [string]$ExpectedMarker = "",
        [string[]]$AllowedErrorPatterns = @(),
        [int]$TimeoutSeconds = 120
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Godot
    $startInfo.Arguments = (($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "Could not start Godot."
        }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            throw "Godot timed out after $TimeoutSeconds seconds."
        }
        $output = $stdout.Result + $stderr.Result
        if ($output.Trim()) {
            Write-Host $output.TrimEnd()
        }
        if ($process.ExitCode -ne 0) {
            throw "Godot failed with exit code $($process.ExitCode)."
        }
        if ($output -match '(?m)SCRIPT ERROR:|Parse Error:') {
            throw "Godot reported a script error."
        }
        $errorLines = @($output -split "`r?`n" | Where-Object { $_ -match '^ERROR:' })
        foreach ($line in $errorLines) {
            $allowed = $false
            foreach ($pattern in $AllowedErrorPatterns) {
                if ($line -match $pattern) {
                    $allowed = $true
                    break
                }
            }
            if (-not $allowed) {
                throw "Godot reported an error: $line"
            }
        }
        if ($ExpectedMarker -and $output -notmatch [regex]::Escape($ExpectedMarker)) {
            throw "Godot did not print $ExpectedMarker."
        }
    }
    finally {
        if (-not $process.HasExited) {
            $process.Kill()
        }
        $process.Dispose()
    }
}

function Initialize-NumblopProject {
    param(
        [Parameter(Mandatory)] [string]$Godot,
        [Parameter(Mandatory)] [string]$RepoRoot
    )

    $translationOutputs = @(
        (Join-Path $RepoRoot "localization\strings.en.translation"),
        (Join-Path $RepoRoot "localization\strings.cs.translation")
    )
    $missingTranslations = @($translationOutputs | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($missingTranslations.Count -gt 0) {
        Invoke-NumblopGodot -Godot $Godot -Arguments @(
            "--headless", "--path", $RepoRoot, "--import"
        ) -AllowedErrorPatterns @(
            "Cannot open file 'res://localization/strings\.(en|cs)\.translation'",
            "Failed loading resource: res://localization/strings\.(en|cs)\.translation"
        )
        foreach ($path in $translationOutputs) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Godot did not generate translation resource: $path"
            }
        }
    }

    Invoke-NumblopGodot -Godot $Godot -Arguments @(
        "--headless", "--path", $RepoRoot, "--import"
    )
}

Export-ModuleMember -Function Resolve-NumblopGodot, Invoke-NumblopGodot, Initialize-NumblopProject
